#!/usr/bin/env julia
# Robust WGL startup + Cairo fallback (fixed color names + no soft-scope warnings)

function main()
    import WGLMakie
    using Makie
    import GeometryBasics
    import Colors

    # helpers
    p3(x,y,z) = GeometryBasics.Point{3,Float32}((Float32(x),Float32(y),Float32(z)))

    function cuboid_edges(cx,cy,cz,wx,wy,hz)
        dx,dy,dz = wx/2, wy/2, hz/2
        corners = [
            p3(cx-dx, cy-dy, cz-dz),
            p3(cx+dx, cy-dy, cz-dz),
            p3(cx+dx, cy+dy, cz-dz),
            p3(cx-dx, cy+dy, cz-dz),
            p3(cx-dx, cy-dy, cz+dz),
            p3(cx+dx, cy-dy, cz+dz),
            p3(cx+dx, cy+dy, cz+dz),
            p3(cx-dx, cy+dy, cz+dz),
        ]
        edges = [(1,2),(2,3),(3,4),(4,1),(5,6),(6,7),(7,8),(8,5),(1,5),(2,6),(3,7),(4,8)]
        return [(corners[a], corners[b]) for (a,b) in edges]
    end

    function draw_arrow_simple!(sc, tail, tip; linewidth=6.0, color=Colors.RGBA(0.95,0.78,0.20,1.0), headr=0.16f0)
        lines!(sc, [tail, tip], linewidth=linewidth, color=color)
        mesh!(sc, GeometryBasics.Sphere(tip, headr), color=color, shading=false)
    end

    # build scene
    scene = Scene(size=(1000,700), show_axis=false, camera=cam3d!)

    # boxes
    for seg in cuboid_edges(0.0,0.0,1.4,8.0,5.0,1.6)
        lines!(scene, [seg[1], seg[2]]; linewidth=2, color=Colors.RGBA(0.2,0.4,0.6,0.9))
    end
    for seg in cuboid_edges(0.0,0.0,-0.8,8.0,5.0,1.0)
        lines!(scene, [seg[1], seg[2]]; linewidth=2, color=Colors.RGBA(0.12,0.12,0.12,0.9))
    end

    # example fluxes
    SW_down, SW_ref, LW_up, LW_down, OLR, H_flux, LE_flux =
        341f0, 101f0, 396f0, 339f0, 239f0, 17f0, 80f0

    # arrows
    draw_arrow_simple!(scene, p3(0.0, -12.0, 4.0),  p3(0.0, 0.0, -1.2); linewidth=6, color=Colors.RGBA(0.95,0.78,0.20,1.0))
    draw_arrow_simple!(scene, p3(4.5, 0.6, -0.4), p3(4.6, -6.0, 3.0); linewidth=4.5, color=Colors.RGBA(0.95,0.78,0.20,1.0))
    draw_arrow_simple!(scene, p3(-3.0, 0.0, -1.2), p3(-3.0, 0.0, 2.0); linewidth=6, color=Colors.RGBA(0.88,0.18,0.18,1.0))
    draw_arrow_simple!(scene, p3(-1.8, 0.0, 2.0),  p3(-1.8, 0.0, -1.2); linewidth=6, color=Colors.RGBA(0.88,0.18,0.18,1.0))

    # ----- Bonito / WGL attempt -----
    app = nothing
    try
        import Bonito
        app = Bonito.App(() -> nothing)
        Bonito.wait_for_ready(app; timeout=5)
        println("Bonito created and ready: ", typeof(app))
    catch e
        @warn "Bonito unavailable or failed to start — WGL attach will be skipped." exception=(e,)
        app = nothing
    end

    # try attach methods (safe sequence)
    function try_attach(app, scene)
        # candidates as thunks
        candidates = [
            () -> isdefined(WGLMakie, :screen) ? getproperty(WGLMakie, :screen)(app, scene) : throw(ErrorException("WGLMakie.screen not available")),
            () -> isdefined(WGLMakie, :start_web_session) ? getproperty(WGLMakie, :start_web_session)(scene; wait=false) : throw(ErrorException("WGLMakie.start_web_session not available")),
            () -> isdefined(WGLMakie, :start_web_session) ? getproperty(WGLMakie, :start_web_session)(scene) : throw(ErrorException("WGLMakie.start_web_session not available")),
            () -> isdefined(WGLMakie, :start_webserver) ? getproperty(WGLMakie, :start_webserver)(scene) : throw(ErrorException("WGLMakie.start_webserver not available")),
            () -> isdefined(WGLMakie, :bind!) ? getproperty(WGLMakie, :bind!)(app, scene) : throw(ErrorException("WGLMakie.bind! not available")),
            () -> isdefined(WGLMakie, :publish) ? getproperty(WGLMakie, :publish)(scene, app) : throw(ErrorException("WGLMakie.publish not available")),
            () -> begin display(scene); :displayed end
        ]

        for (i, c) in enumerate(candidates)
            println("Trying attach candidate $i ...")
            try
                res = c()
                println("Attach candidate $i succeeded: ", typeof(res))
                return true
            catch err
                println("Candidate $i failed: ", err)
            end
        end
        return false
    end

    attached = false
    if app !== nothing
        attached = try_attach(app, scene)
    end

    if attached && app !== nothing
        try
            url = Bonito.connection_url(app)
            println("Bonito connection URL: ", url)
        catch e
            println("Could not query Bonito.connection_url(): ", e)
        end
    end

    # ----- Cairo fallback (uses explicit Colors.RGB / Colors.RGBA) -----
    if !attached
        @warn "No WGL attach succeeded — writing static Cairo output (PNG + SVG)."
        try
            using CairoMakie
            # use Colors explicit constructors — compatible across versions
            fig = Figure(resolution=(1200,800))
            ax = Axis(fig[1,1]; xticks = [], yticks = [], backgroundcolor = Colors.RGB(1.0,1.0,1.0))
            hidexdecorations!(ax); hideydecorations!(ax)

            # 2D layout
            W, H = 1200, 800
            surf_center = (W*0.5, H*0.18)
            atm_center  = (W*0.5, H*0.40)
            surf_w, surf_h = W*0.5, H*0.12
            atm_w, atm_h   = W*0.6, H*0.20

            rect!(ax, Point2f(surf_center[1]-surf_w/2, surf_center[2]-surf_h/2), surf_w, surf_h;
                  color = Colors.RGBA(0.96,0.99,0.97,1.0), strokecolor=Colors.RGBA(0.4,0.4,0.4,0.9))
            rect!(ax, Point2f(atm_center[1]-atm_w/2, atm_center[2]-atm_h/2), atm_w, atm_h;
                  color = Colors.RGBA(0.88,0.95,0.98,1.0), strokecolor=Colors.RGBA(0.4,0.6,0.8,0.9))

            function arrow_width(f) return 1.5 + 12 * clamp(f/420, 0, 1) end
            function draw_arrow2d!(ax, tail::Tuple, tip::Tuple, width::Float64; color=Colors.RGBA(0.95,0.78,0.20,0.95))
                tx, ty = tail; px, py = tip
                vx, vy = px - tx, py - ty
                L = hypot(vx, vy)
                if L == 0 return end
                ux, uy = vx/L, vy/L
                nx, ny = -uy, ux
                ox, oy = nx*(width/2), ny*(width/2)
                body = [
                    Point2f(tx - ox, ty - oy),
                    Point2f(px - 0.15*ox, py - 0.15*oy),
                    Point2f(px - ox, py - oy),
                    Point2f(px + ox, py + oy),
                    Point2f(px + 0.15*ox, py + 0.15*oy),
                    Point2f(tx + ox, ty + oy)
                ]
                poly!(ax, body; color=color, strokecolor = Colors.RGBA(0,0,0,0.12))
                head = [Point2f(px - 0.6*ox, py - 0.6*oy), Point2f(px, py), Point2f(px + 0.6*ox, py + 0.6*oy)]
                poly!(ax, head; color=color, strokecolor = Colors.RGBA(0,0,0,0.12))
            end

            draw_arrow2d!(ax, (W*0.5, H*0.98), (W*0.5, surf_center[2]+surf_h/2), arrow_width(SW_down))
            draw_arrow2d!(ax, (W*0.6, surf_center[2]+surf_h/2), (W*0.82, H*0.92), arrow_width(SW_ref))
            draw_arrow2d!(ax, (W*0.36, surf_center[2]+surf_h/2), (W*0.36, atm_center[2]-atm_h/2), arrow_width(LW_up); color=Colors.RGBA(0.88,0.18,0.18,0.95))
            draw_arrow2d!(ax, (W*0.46, atm_center[2]-atm_h/2), (W*0.46, surf_center[2]+surf_h/2), arrow_width(LW_down); color=Colors.RGBA(0.88,0.18,0.18,0.95))
            draw_arrow2d!(ax, (W*0.22, atm_center[2]+atm_h/2), (W*0.06, H*0.98), arrow_width(OLR); color=Colors.RGBA(0.88,0.18,0.18,0.95))
            draw_arrow2d!(ax, (W*0.72, surf_center[2]+surf_h/2), (W*0.82, surf_center[2]+surf_h/2 + H*0.06), arrow_width(H_flux); color=Colors.RGBA(0.12,0.12,0.12,0.95))
            draw_arrow2d!(ax, (W*0.82, surf_center[2]+surf_h/2), (W*0.92, surf_center[2]+surf_h/2 + H*0.07), arrow_width(LE_flux); color=Colors.RGBA(0.12,0.12,0.12,0.95))

            save("trenberth_fallback.png", fig)
            save("trenberth_fallback.svg", fig)
            println("Wrote trenberth_fallback.png and trenberth_fallback.svg")
        catch e
            @error "Cairo fallback failed" exception=(e,)
        end
    else
        println("WGL attach succeeded. Keep Julia process alive (Ctrl-C to exit).")
        while true
            sleep(3600)
        end
    end
end

# run main
main()
