#' Maximum Urban heat island intensity
#' @title Maximum urban heat island intensity
#' @description Maximum urban heat island intensity calculated according to Theeuwes(2016). The UHImax is defined as the maximum
#' temperature difference between the urban and rural site for a time period starting on Day0 08:00 up to Day1 07:00. The formula
#' requires input from one rural reference station and the sky view factor and vegetation fraction inside the city.
#' Temperature data from several stations inside the city is recommended to validate the model.
#' @param SVF the sky view factor at the locations
#' @param fveg vegetation fraction in a 500 meter radius
#' @param S hourly maximum solar irradiance at the rural site summed over 24 hours devided by 24.
#' Start=day0 01:00, Stop=day1 00:00. NOTE: Solar irradiance is has the units K/(ms) --> devide W/m2 by air density (approximately 1.1)
#' and specific heat capacity (approximately 1005).
#' @param DTR diurnal temperature range calculated from Tmax and Tmin in the rural area. Start=day0 08:00, Stop=day1 07:00
#' @param U mean 10 meter wind speed (m/s) from hourly data from the rural site. Start=day0 08:00 Stop=day1 07:00
#' @param a1,a2,a3,lambda fitting coeficients
#' @source \url{https://rmets.onlinelibrary.wiley.com/doi/full/10.1002/joc.4717}
#' @param wd work directory, only used when write.file==TRUE
#' @export
UHImax<-function(SVF,fveg,S,DTR,U,a1=2,a2=1,a3=1,lambda=3.6){
  UHImax<-(a1-a2*SVF-a3*fveg)*((S*(DTR^3)/U)^(1/lambda))
  return(UHImax)
}

#'@title Events with urban rural temperature relations
#'@description Determines the days without distrubances of weather phenomena such as frontal systems or fog.
#'Classified according to the rules used in Theeuwes(2016). The following rules are checked:
#'\itemize{
#'\item If the hourly rainfall exceeds 0.3mm
#'\item Or if  the relative humidity is above 80\%
#'\item Or if the changes is the wind are more than 2m/s
#'\item Or if the daily mean wind speed is lower than 0.5m/s (This because it is hard to measure these low wind speeds)
#'}
#'These settings will leave 25-40\% of the data available for further analysis.
#'@param time time of the measurements in hours
#'@param rain rainfall in mm
#'@param wind wind speed in m/s
#'@param rh relative humidity in \%
#'@source \url{https://rmets.onlinelibrary.wiley.com/doi/full/10.1002/joc.4717}
#'@export
uhi_sub<-function(time,rain,wind,rh){
  df<-data.frame(time,"rain"=as.numeric(rain),"wind"=as.numeric(wind),"rh"=as.numeric(rh))
  df$hour<-cut(df$time,breaks="hour")
  df$day<-as.Date(df$time)
  df$wind_diff<-c(diff(df$wind),NA)
  start=which(hour(df$hour)==8)
  stop=which(hour(df$hour)==7)

  if(start[1]>stop[1]){
    stop<-stop[2:length(stop)]
  }

  if(length(start) != length(stop)){
    start<-start[1:length(stop)]
  }

  R<-mapply(function(y,z) sum(df$rain[y:z]/24,na.rm=TRUE)<0.3,
               y=start,
               z=stop)
  RH<-mapply(function(y,z) mean(df$rh[y:z],na.rm=TRUE)<80,
            y=start,
            z=stop)

  U<-mapply(function(y,z) all(df$wind_diff[y:z]<2),
            y=start,
            z=stop)

  U2<-mapply(function(y,z) mean(df$wind[y:z])>0.5,
            y=start,
            z=stop)
  meteo<-data.frame(R,RH,U,U2)
  meteo<-apply(meteo,1,all)

  ss<-data.frame("start"=df$hour[start],"stop"=df$hour[stop],
                 "Rain"=R,
                 "rh"=RH,
                 "Wind"=U,
                 "Wind2"=U2,
                 "Select"=meteo)
  return(ss)
}

#' Calculate the mean solar irradiance
#' @title Mean solar irradiance
#' @description Mean solar irradiance according to Theeuwes(2016). Calculate for the
#' rural site for a time period starting on Day0 01:00 up to Day1 00:00.
#' @param time time vector in POSIXct with at least an hourly resolution
#' @param solar_irr solar irradiance measurements at the times of the time vector
#' @importFrom dplyr %>% group_by summarize
#' @source \url{https://rmets.onlinelibrary.wiley.com/doi/full/10.1002/joc.4717}
#' @export
calc_S<-function(time,solar_irr){
  df<-data.frame(time,"solar_irr"=as.numeric(solar_irr))
  df$hour<-cut(df$time,breaks="hour")
  df$day<-as.Date(df$time)
  df.h<-df %>% group_by(day,hour) %>% summarize(S=mean(solar_irr,na.rm=TRUE))
  df.h<-data.frame(df.h)
  df.h$hour<-as.POSIXct(df.h$hour)
  start=which(hour(df.h$hour)==1)
  stop=which(hour(df.h$hour)==0)

  if(start[1]>stop[1]){
    stop<-stop[2:length(stop)]
  }

  if(length(start) != length(stop)){
    start<-start[1:length(stop)]
  }

  S_out<-mapply(function(y,z) sum(df.h$S[y:z],na.rm=TRUE)/24,
                y=start,
                z=stop)
  ss<-data.frame("start"=df.h$hour[start],"stop"=df.h$hour[stop],"S"=S_out)
  return(ss)
}

#' Calculate the Diurnal temperature range
#' @title Diurnal temperature range
#' @description Diurnal temperature range calculated according to Theeuwes(2016). The DTR is defined as the maximum
#' temperature difference of the rural site for a time period starting on Day0 08:00 up to Day1 07:00.
#' @param time time vector in POSIXct with at least an hourly resolution
#' @param temperature temperature measurmenents at the times of the time vector
#' @importFrom lubridate hour minute
#' @source \url{https://rmets.onlinelibrary.wiley.com/doi/full/10.1002/joc.4717}
#' @export
calc_DTR<-function(time,temperature){
  df<-data.frame(time,"T"=as.numeric(temperature))
  df$hour<-cut(df$time,breaks="hour")
  df$day<-as.Date(df$time)
  # df.h<-df %>% group_by(day,hour) %>% summarize(T=mean(temperature,na.rm=TRUE))
  # df.h<-data.frame(df.h)
  # df.h$hour<-as.POSIXct(df.h$hour)
  start=which(hour(df$time)==8 & minute(df$time)==0)
  stop=which(hour(df$time)==7  & minute(df$time)==0)

  if(start[1]>stop[1]){
    stop<-stop[2:length(stop)]
  }

  if(length(start) != length(stop)){
    start<-start[1:length(stop)]
  }

  Tmin<-mapply(function(y,z) min(df$T[y:z],na.rm=TRUE),
               y=start,
               z=stop)
  Tmax<-mapply(function(y,z) max(df$T[y:z],na.rm=TRUE),
               y=start,
               z=stop)
  DTR<-Tmax-Tmin
  ss<-data.frame("start"=df$hour[start],"stop"=df$hour[stop],"DTR"=DTR)
  return(ss)
}

#' Calculating mean wind speeds
#' @title Mean wind speed
#' @description Mean wind speed calculated according to Theeuwes(2017). The mean wind speed is defined as the mean
#' wind at the rural site for a time period starting on Day0 08:00 up to Day1 07:00.
#' @param time time vector in POSIXct with at least an hourly resolution
#' @param wind wind speed at the times of the time vector
#' @source \url{https://rmets.onlinelibrary.wiley.com/doi/full/10.1002/joc.4717}
#' @export
calc_U<-function(time,wind){
  df<-data.frame(time,"wind"=as.numeric(wind))
  df$hour<-cut(df$time,breaks="hour")
  df$day<-as.Date(df$time)
  df.h<-df %>% dplyr::group_by(day,hour) %>% dplyr::summarize(W=mean(wind,na.rm=TRUE))
  df.h<-data.frame(df.h)
  df.h$hour<-as.POSIXct(df.h$hour)
  start=which(hour(df.h$hour)==8)
  stop=which(hour(df.h$hour)==7)

  if(start[1]>stop[1]){
    stop<-stop[2:length(stop)]
  }

  if(length(start) != length(stop)){
    start<-start[1:length(stop)]
  }

  W_out<-mapply(function(y,z) mean(df.h$W[y:z],na.rm=TRUE),
                y=start,
                z=stop)
  ss<-data.frame("start"=df.h$hour[start],"stop"=df.h$hour[stop],"W"=W_out)
  return(ss)
}

#' Calculating maximum urban heat island effect
#' @title maximum urban heat island
#' @description Maximum urban heat island (UHImax) calculated according to Theeuwes(2016). The hourly mean temperature difference
#' which is maximum within the period starting on Day0 08:00 up to Day1 07:00 is the UHImax
#' @param time time vector in POSIXct with at least an hourly resolution
#' @param Tref Reference temperature from the rural site
#' @param Tcity Temperature within the city for-which the UHImax is calculated
#' @importFrom dplyr %>%
#' @source \url{https://rmets.onlinelibrary.wiley.com/doi/full/10.1002/joc.4717}
#' @export
calc_UHImax<-function(time,Tref,Tcity){
  df<-data.frame(time,"Tref"=as.numeric(Tref),"Tcity"=as.numeric(Tcity))
  df$hour<-cut(df$time,breaks="hour")
  df$day<-as.Date(df$time)
  df.h<-df %>% dplyr::group_by(day,hour) %>% dplyr::summarize(UHImax=mean(Tcity-Tref,na.rm=TRUE))
  df.h<-data.frame(df.h)
  df.h$hour<-as.POSIXct(df.h$hour)
  start=which(hour(df.h$hour)==8)
  stop=which(hour(df.h$hour)==7)

  if(start[1]>stop[1]){
    stop<-stop[2:length(stop)]
  }

  if(length(start) != length(stop)){
    start<-start[1:length(stop)]
  }

  UHI_out<-mapply(function(y,z) max(df.h$UHImax[y:z],na.rm=TRUE),
                  y=start,
                  z=stop)
  ss<-data.frame("start"=df.h$hour[start],"stop"=df.h$hour[stop],"UHImeasured"=UHI_out)
  return(ss)
}

#' @title Calculate Maximum urban heat island from observations
#' @description Calculates the maximum urban heat island based on city observations and
#' rural observations. Data is prepared for UHImax.
#' @param STN station number
#' @param svf Sky view factor of the city station
#' @param fveg Vegetation fraction of the city station
#' @param city_T `RDS` file with the filtered city temperatures
#' @param rural_T `data.frame` with rural observations
#' @param rural_meteo `data.frame` with rural meteorological parameters prepared according to Theeuwes (2017)
#' @param write.file Optional, TRUE/FALSE
#' @importFrom utils write.table
#' @export
uhimax_params<-function(STN,svf,fveg,city_T,rural_T,
                        rural_meteo,wd=NULL,write.file=FALSE){
  Cp<-1005 #specific heat capacity
  message("Reading city temperature data")
  stn<-readRDS(city_T)

  message("Merging with rural temperature data")
  wur_cabauw<-merge(x=stn$interpolated_time,y=rural_T,by.x="new_time",by.y="time")
  wur_cabauw<-wur_cabauw[complete.cases(wur_cabauw),]

  message("Calculating the maximum UHI from temperature observations")
  UHI<-calc_UHImax(time = wur_cabauw$new_time,
                   Tcity = wur_cabauw$T_int,
                   Tref = wur_cabauw$T)
  UHI$Tcity<-calc_U(time=wur_cabauw$new_time,wur_cabauw$T_int)$W
  UHI$Tref<-calc_U(time=wur_cabauw$new_time,wur_cabauw$T)$W
  UHI<-merge(UHI,rural_meteo,by=c("start","stop"))
  UHI$svf<-as.numeric(svf)
  UHI$fveg<-as.numeric(fveg)
  UHI$Cp<-Cp
  UHI$stn<-STN

  if(write.file==TRUE){
    message("writing file")
    file_name=paste0(wd,STN,"_UHIparams.txt") # stored previous files in folder "UHImax/"
    write.table(UHI,file_name,
                row.names = FALSE,
                col.names = TRUE,
                sep=",")
  }

  return(UHI)
}
