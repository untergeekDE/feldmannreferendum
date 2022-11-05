#' generiere_balken.R
#' 
#' Hilfsfunktionen für die Grafikdarstellung in Datawrapper
#' Produzieren den Code für die Fake-Balken
#' 
# Hilfsfunktion: Die Prozent-Balken ja/nein generieren
#
# Konstante: Breite der Pufferzellen in px
puffer = 100

generiere_balken <- function (wb, ja, nein, auszählung_beendet) {
  if (wb == 0) {
    quorum = 0
  } else {
    quorum = (ja / wb * 100)
  }
  ja_breite_prozent <- ifelse(quorum >= 30,
                              100,
                              floor(quorum / 0.3))
  # Nein-Balken: 
  nein_breite_prozent <- floor(ifelse(nein==0,0, nein / ja) *
                                 # Berechnen als Anteil des Ja-Balkens
                                 ifelse(quorum >= 30,
                                        # Wenn Quorum erreicht, nimmt Ja-Balken volle Breite ein - 
                                        100,
                                        # sonst nur diese Breite -
                                        ja_breite_prozent))
  # FALLS mehr Nein-Stimmen als Ja-Stimmen abgegeben werden, 
  # könnte der Algorithmus inkorrekte Daten darstellen, deshlab der Cap bei 100.
  if (nein_breite_prozent > 100) { nein_breite_prozent <- 100}
  
  # Funktion in der Funktion: Die Markierungs-Balken brauchen wir 2x.
  # Wenn das Quorum erreicht ist, brauchen wir zwei Zellen, um den Strich zu 
  # produzieren: 
  markierungsbalken <- function(quorum) {
    mbalkencode <- ifelse(quorum >= 30,
                          # Wenn Quorum erreicht (ja-Balken 100%), 
                          # brauchen wir zwei Zellen, um die Markierung darzustellen
                          paste0(
                            "<span style='width:",
                            # Welchen Anteil haben die 30% am tatsächlich erreichten Quorum? 
                            floor(30 / quorum * 100), # Integer!
                            "%; height:8px;border-right: 4px solid #000;
                   ;text-align:center;'></span>",
                            "<span style ='width:",
                            100 - floor(30 / quorum * 100),
                            "%; height:8px;'></span>"),
                          # Nur eine Zelle (100%), wenn das Quorum nicht erreicht ist
                          "<span style='width:100%;height:8px;border-right:4px solid #000;'></span>")
    return(paste0(
      # Container
      "<span style='height:8px;display: flex;justify-content: space-around;align-items: flex-end; width: 100%;'>",
      # Puffer-Zelle linke Spalte
      "<span style='width:",
      puffer,
      "px; '>&nbsp;</span>",
      mbalkencode,
      "</span>"))
  } 
  # Den Fake-Balken-Code generieren
  balkencode <- paste0(
    "Ja-Stimmen: (",
    # Läuft die Auszählung noch?
    ifelse(auszählung_beendet,"","derzeit "),
    format(quorum,decimal.mark=",",nsmall=1, digits=3),
    "% der Wahlberechtigten; Quorum ",
    ifelse(quorum >= 30,
           "erreicht)",
           "nicht erreicht)"),
    # Container Fakebalken 1: Ja-Stimmen
    "<span style='height:32px;display:flex;flex-direction:column;width:100%;'>",
    markierungsbalken(quorum),
    # Container Ja-Stimmen-Balken
    "<span style='height:16px;display: flex;justify-content: space-around;align-items: flex-end; width: 100%;'>",
    # Pufferzelle mit Stimmenzahl
    "<span style='width:",puffer,"px; text-align:left;font-size:90%;'>",
    format(ja,decimal.mark = ",",big.mark = "."),
    "</span>",
    # Blauer Balken
    "<span style='width:",
    ja_breite_prozent, #integer!
      "%; background:#005293; height:16px;'></span>",
    # Grauer Balken
    "<span style='width:",
    100-ja_breite_prozent, #integer!
    "%; background:#a6abb0; height:16px;",
    # Wenn Quorum nicht erreicht, Zielmarken-Strich am rechten Rand des Balkens
    ifelse(quorum < 30, "border-right: 4px solid #000;",""),
    "'></span>",
    # Ende Container Ja-Stimmen-Balken
    "</span>",
    markierungsbalken(quorum),
    # Ende Container Fakebalken 1
    "</span>",
    "Nein-Stimmen:",
    # Container Fakebalken 2
    "<span style='height:32px;display:flex;flex-direction:column;width:100%;'>",
    # Container Nein-Stimmen-Balken
    "<span style='height:16px;display: flex;justify-content: space-around;align-items: flex-end; width: 100%;'>",
    # Pufferzelle mit Stimmenzahl
    "<span style='width:",puffer,"px; text-align:left;font-size:90%;'>",
    format(nein,decimal.mark = ",",big.mark = "."),
    "</span>",
    # Roter Balken
    "<span style='width:",
    nein_breite_prozent, #integer!
    "%; background:#d34600; height:16px;'></span>",
    # Grauer Balken
    "<span style='width:",
    100-nein_breite_prozent, #integer!
    "%; background:#a6abb0; height:16px;'></span>",
    # Ende Container Ja-Stimmen-Balken
    "</span>",
    # Ende Container Fakebalken 2
    "</span>",
    "Verhältnis Ja:Nein: ",
    ifelse(ja+nein == 0, "", format(ja/(ja+nein)*100,decimal.mark=",",nsmall=1, digits=3)),"%:",
    ifelse(ja+nein == 0, "", format(nein/(ja+nein)*100,decimal.mark=",",nsmall=1, digits=3)),"%"
  )
}

generiere_auszählungsbalken <- function(ausgezählt,anz,max,ts) {
  annotate_str <- paste0("Anteil der Wahlberechtigten, die die Auszählung umfasst",
                        # Container Fake-Balken
                         "<span style='height:24px;display: flex;justify-content: space-around;align-items: flex-end; width: 100%;'>",
                            # Vordere Pufferzelle 70px  
                            "<span style='width:70px; text-align:center;'>",
                            ausgezählt,
                            "%</span>",
                            # dunkelblauer Balken
                            "<span style='width:",
                            ausgezählt,
                            "%; background:#002747; height:16px;'></span>",
                            # grauer Balken
                            "<span style='width:",
                            100-ausgezählt,
                            "%; background:#CCC; height:16px;'></span>",
                            # Hintere Pufferzelle 5px
                            "<span style='width:5px;'></span>",
                        # Ende Fake-Balken
                        "</span>",
                         "<br><br><strong>Stand: ",
                         format.Date(ts, "%d.%m.%y, %H:%M Uhr"),
                         "</strong> - ",
                         anz," von ",max,
                         " Stimmbezirken ausgezählt<br>"
  )
  
}

