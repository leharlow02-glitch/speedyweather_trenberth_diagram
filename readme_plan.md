README.TXT



Main goal - gets global mean and global sum for different fluxes



Uses: SpeedyWeather, CairoMakie, GLMakie



Process:

###### **Step 1 - run model** 

* Note - must manually add radiation and surface fluxes 

###### 

###### **Step 2 - create function that calculates sum or mean of field in spectral space**

* Transforms to spectral space 
* 'a00' is the mean value of the field - this is because its the first coefficient in spherical harmonic decomposition
* Must get mean by dividing by norm\_sphere as spherical harmonics is in wrong coordinates
* Can get total sum by multiplying it by 4pi x planet radius
* Can choose either mean or sum when using function



###### **Step 3 - computing fluxes while simulation is running**

* Instead of putting 'simulation' in the argument of a function calculating fluxes (which requires whole sim to run), use 'diagn' which allows you to calculate flux during simulation instead of at the end of a sim
* Add mean and sum functions inside this as you need to calculate these at each step 
* Then takes each field, converts to a float, calculates mean or sum (Boolean True or False for this bit) and calculates longwave, shortwave, and 'net energy flux' i.e. everything needed for Trenberth without clouds
* Can add clouds later



###### **Step 4 - adding a callback mechanism**

* After x number of timesteps (when callback is used)
* Creating a dictionary of all variables which adds a new value to each flux after each timestep
* Returns a function (come back to this as not sure what is being returned)

###### 

###### **Step 5 - creating useful functions**

* Print dictionary of flux long names 
* Convert time into float time 



###### **Step 6 - Initialising SpeedyWeather.jl using callbacks**

* Initialise SpeedyWeather.jl
* Define number of steps before starting (defines dictionary before starting instead of adding length to vector whilst running) - computationally efficient
* Set counter to 1 and store initial conditions
* Create res0 which uses the calculating Trenberth function to get initial values 
* For (k, v) in res0 run the callback using push!
* 2 options for this so check 



Step 7 - finalise SpeedyWeather.jl

* Finalize!





Output of callback function:

* For now we have a vector of values for each flux at each timestep
* We need to think about memory - would it be best to store animation as a gif without saving the values to prevent too much memory being used
