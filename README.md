# feldmannreferendum

R-Routinen, um die Abstimmungsergebnisse des Referendums in Frankfurt am 6. November 2022 auf die hessenschau.de-Website zu bringen. 

## Todo
- Fehlerbehandlung für aktualisiere_fom() und aktualisiere_karten()
- Barchart-Generierung in fom()
- Ja-Stimmen in fom()
- Daten in der Tooltipps-Box in den Karten

## Datenquelle und Datenformat

Nutzt die Livedaten von https://wahlen.frankfurt.de - die aktuellen Daten nach Wahllokal, Ortsteil und Ortsbezirk sind als CSV-Datei [auf dieser Seite zu finden](https://votemanager-ffm.ekom21cdn.de/2022-11-06/06412000/praesentation/opendata.html). Dort ist das Datenformat auch erklärt: 
 -  datum : Datum des Wahltermins
 -  wahl : Name der Wahl
 -  ags : AGS der Behörde
 -  gebiet-nr : Nummer des Wahlgebiets
 -  gebiet-name : Name des Wahlgebiets
 -  max-schnellmeldungen : Anzahl an insgesamt erwarteten Schnellmeldungen im Wahlgebiet
 -  anz-schnellmeldungen : Anzahl an bisher eingegangenen Schnellmeldungen im Wahlgebiet
 -  A1 : Wahlberechtigte ohne Sperrvermerk 'W'
 -  A2 : Wahlberechtigte mit Sperrvermerk 'W'
 -  A3 : Wahlberechtigte nicht im Wählerverzeichnis
 -  A : Wahlberechtigte insgesamt
 -  B : Wähler
 -  B1 : Wähler mit Wahlschein (idR Briefwähler?)
 -  C : Ungültige Stimmen
 -  D : Gültige Stimmen
 -  D1 : Ja-Stimmen
 -  D2 : Nein-Stimmen
 
 ## Wann gibt es wo Daten?
 
 Soweit ich es sehen kann: 
 - Nicht ausgezählte Wahllokale enthalten NA bei Wahlberechtigten/Wählern
 - Ortsteile haben, solang sie noch nicht ganz ausgezählt sind, fiktive Wahlberechtigten-Zahlen - die dann nur die Wahllokale abbilden, die bereits ausgezählt sind. (Beispiel: Ein Ortsteil hat 3000 Wahlberechtigte in 3 Wahllokal-Bezirken mit jeweils 1000 Wahlberechtigten - solange nur 2 ausgezählt sind, wird für den Ortsteil eine Wahlberechtigten-Anzahl von 2000 angezeigt.)
 - Briefwahl"lokale" - die Wahllokale mit den Nummern 9xx-xx - haben 0 Wahlberechtigte.  