library(readr)
library(lubridate)
library(tidyr)
library(stringr)
library(dplyr)


# Hilfsroutinen, die die Index-Dateien generieren
source("lies_aktuellen_stand.R")



tmp_df <- lies_stand(stand_url)

#---- Generiere Zentroide aus JSON ----
library(jsonlite)
# Hole die Wahlergebnisse der OB-Wahl 2018 - mit den Wählerzahlen.
#
# Nach Auskunft von Michael Wolfsteiner, Leiter des Wahlamts, 
# ist die Zahl der Wahlberechtigen derzeit bei ca. 510.000
# (endgültig steht das erst am 6.11. um 18 Uhr fest).
# Daran gemessen sind die hier verwendeten Zahlen um ca 1% zu niedrig -
# auch wenn es nach Stadtteil stärker schwanken wird: 
# ich glaube, das kann man verschmerzen. 

ob2018stadtteile <- read_delim("index/ob2018stadtteile.csv", 
                               delim = ";", 
                               escape_double = FALSE, 
                               locale = locale(date_names = "de",
                                               decimal_mark = ",",
                                               grouping_mark = ".",   
                                               encoding = "ISO-8859-1"),
                               trim_ws = TRUE)


tmp <- fromJSON("shapefile/zentroide.geojson")
# unnest_wider dauert eeeewig lang, aber funktioniert
stadtteile_df <- tibble(nr=tmp$features$properties$STT,
                        name = tmp$features$properties$NAME,
                        latlon = tmp$features$geometry$coordinates) %>% 
  unnest_wider(latlon) %>% 
  rename(lat =4, lon = 3) %>% 
  left_join(ob2018stadtteile %>% 
              select(nr = Stadtteilnummer,
                     wahlberechtigt_2018 = 5,
                     waehler_2018 = 6,
                     gueltig_2018 = 11,
                     feldmann_2018 = 14),
            by = "nr")




# df enthält jetzt:
# - nr (des Stadtteils)
# - name
# - lat
# - lon
write_csv(stadtteile_df,"index/stadtteile.csv")


#---- Die Index-Daten alle in ein handliches .rda verpacken----
stadtteile_df <- read_csv("index/stadtteile.csv")
zuordnung_wahllokale_df <- read_csv("index/zuordnung_wahllokale.csv")
opendata_wahllokale_df <- read_csv2("index/opendata-wahllokale.csv") 

save(stadtteile_df,zuordnung_wahllokale_df,opendata_wahllokale_df,file ="index/index.rda")

