% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/UHImax.R
\name{calc_S}
\alias{calc_S}
\title{Mean solar irradiance}
\source{
\url{https://rmets.onlinelibrary.wiley.com/doi/full/10.1002/joc.4717}
}
\usage{
calc_S(time, solar_irr)
}
\arguments{
\item{time}{time vector in POSIXct with at least an hourly resolution}

\item{solar_irr}{solar irradiance measurements at the times of the time vector}
}
\description{
Mean solar irradiance according to Theeuwes(2016). Calculate for the
rural site for a time period starting on Day0 01:00 up to Day1 00:00.
}
\details{
Calculate the mean solar irradiance
}
