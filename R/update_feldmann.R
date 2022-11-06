library(pacman)

# Laden und ggf. installieren
p_load(this.path)
p_load(readr)
p_load(lubridate)
p_load(tidyr)
p_load(stringr)
p_load(dplyr)
p_load(DatawRappr)

rm(list=ls())

# Aktuelles Verzeichnis als workdir
setwd(this.path::this.dir())
# Aus dem R-Verzeichnis eine Ebene rauf
setwd("..")


source("R/messaging.R")
source("R/lies_aktuellen_stand.R")
source("R/aktualisiere_karten.R")
source("R/generiere_balken.R")  


#----aktualisiere_fom() ----
# fom ist das "Feldmann-o-meter", die zentrale Grafik mit dem Stand der Auszählung.

aktualisiere_fom <- function(wl_url = stimmbezirke_url) {
  
  # Einlesen: Feldmann-o-meter-Daten so far. 
  # Wenn die Daten noch nicht existieren, generiere ein leeres df. 
  if(file.exists("daten/fom_df.rds")) {
    fom_df <- readRDS("daten/fom_df.rds")
  } else {
    # Leeres df mit einer Zeile
    fom_df <- tibble(zeitstempel = as_datetime(startdatum),
                           meldungen_anz = 0,
                           meldungen_max = 575,
                           # Ergebniszellen
                           wahlberechtigt = 0,
                           # Mehr zum Wahlschein hier: https://www.bundeswahlleiter.de/service/glossar/w/wahlscheinvermerk.html
                           waehler_regulaer = 0,
                           waehler_wahlschein = 0,
                           waehler_nv = 0,
                           stimmen = 0,
                           stimmen_wahlschein = 0, 
                           ungueltig = 0,
                           gueltig = 0,
                           ja = 0,
                           nein = 0)
    # SAVE kann man sich schenken; df ist schneller neu erzeugt
    # save(feldmann_df,"daten/feldmann_df.rda")
  }
  # Daten zur Sicherheit sortieren, dann die letzte  Zeile rausziehen
  letzte_fom_df <- fom_df %>% 
    arrange(zeitstempel) %>% 
    tail(1)
  # Neue Daten holen (mit Fehlerbehandlung)
  stimmbezirke_df <- lies_gebiet(wl_url) 
  neue_fom_df <- stimmbezirke_df %>% 
    # Namen raus
    select(-name,-nr) %>% 
    # Daten aufsummieren
    summarize(zeitstempel = last(zeitstempel),
      across(2:ncol(.), ~ sum(.,na.rm=T)))
  # Alte und neue Daten identisch? Dann brich ab. 
  if (vergleiche_stand(letzte_fom_df,neue_fom_df)) {
    return(FALSE)
  } else {
    # Archiviere die Rohdaten 
    archiviere(stimmbezirke_df,"daten/stimmbezirke/")
    # Ergänze das fom_df um die neuen Daten und sichere es
    fom_df <- fom_df %>% bind_rows(neue_fom_df)
    saveRDS(fom_df,"daten/fom_df.rds")
    # Bilde das Dataframe
    # Sende die Daten an Datawrapper und aktualisiere
    fom_dw_df <- fom_df %>% 
      mutate(ausgezählt = meldungen_anz / meldungen_max *100) %>% 
      mutate(prozent30 = NA) %>% 
      mutate(quorum = ja / wahlberechtigt * 100) %>% 
      select(ausgezählt, wahlberechtigt, ungueltig, ja, nein, quorum, prozent30) %>% 
      # Noch den Endpunkt der 30-Prozent-Linie
      bind_rows(tibble(ausgezählt = 100, prozent30 = ffm_waehler * 0.3))
    dw_data_to_chart(fom_dw_df,fom_id)
    # Parameter setzen
    alles_ausgezählt <- (neue_fom_df$meldungen_max == neue_fom_df$meldungen_anz)
    if (neue_fom_df$meldungen_anz == 0) {
      quorum = 0
      feldmann_str <- "Es liegen noch keine Auszählungsdaten des Bürgerentscheids vor."
    } else {
      quorum <- (neue_fom_df$ja / neue_fom_df$wahlberechtigt * 100)
      if (quorum >= 30) {
        if (alles_ausgezählt ) {
          feldmann_str <- "Peter Feldmann ist als OB abgewählt."
        } else {
          feldmann_str <- "Nach dem derzeitigen Auszählungsstand wäre Peter Feldmann als OB abgewählt."
        }
      } else {
        if (alles_ausgezählt ) {
          feldmann_str <- "Peter Feldmann bleibt OB von Frankfurt."
        } else {
          feldmann_str <- "Nach dem derzeitigen Auszählungsstand bliebe Peter Feldmann OB von Frankfurt."
        }
      }
    }
    
    # Breite des Balkens: Wenn das Quorum erreicht ist, hat er die volle Breite,
    # wenn nicht, einen Anteil von 30%, um die Entfernung von der Markierung zu zeigen
    
    # Jetzt die Beschreibungstexte mit den Fake-Balkengrafiken generieren
    beschreibung_str <- paste0(
      "Die Abwahl ist beschlossen, wenn mindestens 30 Prozent aller Wahlberechtigten mit &quot;Ja&quot; stimmen.<br/><br>",
      "<b style='font-weight:700;font-size:120%;'>",
      # Erste dynamisch angepasste Textstelle: Bleibt Feldmann?
      feldmann_str,
      "</b><br/><br>",
      generiere_balken(wb = neue_fom_df$wahlberechtigt,
                       ja = neue_fom_df$ja,
                       nein = neue_fom_df$nein,
                       auszählung_beendet = alles_ausgezählt))
    annotate_str <- generiere_auszählungsbalken(
      ausgezählt = floor(neue_fom_df$wahlberechtigt / ffm_waehler * 100),
      anz = neue_fom_df$meldungen_anz,
      max = neue_fom_df$meldungen_max,
      ts = neue_fom_df$zeitstempel)
    briefwahl_anz <- stimmbezirke_df %>% filter(str_detect(nr,"^9")) %>% 
      pull(meldungen_anz) %>% sum()
    briefwahl_max <- stimmbezirke_df %>% filter(str_detect(nr,"^9")) %>% 
      nrow()
    annotate_str <- paste0("<strong>Derzeit sind ",
                           briefwahl_anz,
                           " von ",
                           briefwahl_max, 
                           " Briefwahl-Stimmbezirken ausgezählt.</strong><br/><br/>",
                           annotate_str)
    dw_edit_chart(fom_id,intro = beschreibung_str,annotate = annotate_str)
    dw_publish_chart(fom_id)
    return(TRUE)
  }
}


#---- MAIN ----
# Ruft aktualisiere_fom() auf
# (die dann wieder aktualisiere_karten() aufruft)
check = tryCatch(
  { 
    neue_daten <- aktualisiere_fom(stimmbezirke_url)
  },
  warning = function(w) {teams_warning(w,title="Feldmann: fom")},
  error = function(e) {teams_warning(e,title="Feldmann: fom")})
# Neue Daten? Dann aktualisiere die Karten
if (neue_daten) {
  check = tryCatch(
    { 
      neue_daten <- aktualisiere_karten(stimmbezirke_url)
    },
    warning = function(w) {teams_warning(w,title="Feldmann: Karten")},
    error = function(e) {teams_warning(e,title="Feldmann: Karten")})
  if (neue_daten) {
    # Alles OK, letzte Daten nochmal holen und ausgeben
    fom_df <- readRDS("daten/fom_df.rds") %>% 
      arrange(zeitstempel) %>% 
      tail(1)
    if(fom_df$meldungen_anz > 0) {
      stimmbezirke_df <- lies_gebiet(stimmbezirke_url)
      briefwahl_anz <- stimmbezirke_df %>% filter(str_detect(nr,"^9")) %>% 
        pull(meldungen_anz) %>% sum()
      briefwahl_max <- stimmbezirke_df %>% filter(str_detect(nr,"^9")) %>% 
        nrow()
      fom_update_str <- paste0(
        "<strong>Update OK</strong><br/><br/>",
        fom_df$meldungen_anz,
        " von ",
        fom_df$meldungen_max," Stimmbezirke ausgezählt.<br> ",
                              "Derzeit sind ",
                               briefwahl_anz,
                               " von ",
                               briefwahl_max, 
                               " Briefwahl-Stimmbezirken ausgezählt.<br/>",
        "<ul><li><strong>Quorum zur Abwahl ist derzeit",
        ifelse(fom_df$ja / fom_df$wahlberechtigt < 0.3, " nicht ", " "),
        "erreicht</strong></li>",
        "<li><strong>Anteil der Ja-Stimmen an den Wahlberechtigten: ",
        format(fom_df$ja / fom_df$wahlberechtigt * 100,decimal.mark=",",big.mark=".",nsmall=1, digits=3),"%",
        "</li><li>Ja-Stimmen: ",
        format(fom_df$ja,decimal.mark=",",big.mark="."),
        "</li><li>Nein-Stimmen: ",
        format(fom_df$nein,decimal.mark=",",big.mark="."),
        "</li><li>Verhältnis Ja:Nein: ",
        format(fom_df$ja / (fom_df$ja + fom_df$nein) * 100,decimal.mark=",",big.mark=".",nsmall=1, digits=3),"% : ",
        format(fom_df$nein / (fom_df$ja + fom_df$nein) *100,decimal.mark=",",big.mark=".",nsmall=1, digits=3),"%</li></ul>"
        
      )
      teams_meldung(fom_update_str,title="Feldmann-Referendum")

    }
  } else {
    teams_warning("Neue Stimmbezirk-Daten, aber keine neuen Ortsdaten?")
  }
} 
# Auch hier TRUE zurückbekommen;; alles OK?