library(readr)
library(lubridate)
library(tidyr)
library(stringr)
library(dplyr)
library(teamr)

#' messaging.R
#' 
#' Kommunikation mit Teams
#' 
#' Webhook wird als URL im Environment gespeichert. Wenn nicht dort, dann 

# Webhook schon im Environment? 
if (Sys.getenv("WEBHOOK_REFERENDUM") == "") {
  t_txt <- read_file("")
  Sys.setenv(WEBHOOK_REFERENDUM = t_txt)
}

teams_meldung <- function(...,title="Feldmann-Update") {
  cc <- teamr::connector_card$new(hookurl = Sys.getenv("WEBHOOK_REFERENDUM"))
  cc$title(paste0(title," - ",lubridate::with_tz(lubridate::now(),
                                                 "Europe/Berlin")))
  alert_str <- paste0(...)
  cc$text(alert_str)
  cc$print()
  cc$send()
} 

teams_error <- function(...) {
  alert_str <- paste0(...)
  teams_meldung(title="Feldmann: FEHLER: ", ...)
  stop(alert_str)
} 

teams_warning <- function(...) {
  alert_str <- paste0(...)
  teams_meldung("Feldmann: WARNUNG: ",...)
  warning(alert_str)
} 

