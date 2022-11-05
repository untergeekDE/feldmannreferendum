# feldmannreferendum

R-Routinen, um die Abstimmungsergebnisse des Referendums in Frankfurt am 6. November 2022 auf die hessenschau.de-Website zu bringen. 

V1.0 - Fragen und Anmerkungen jan.eggers (klammeraffe) hr.de

## Aufbau

Das Skript update_feldmann() ist dazu gedacht, 1x pro Minute aufgerufen zu werden. 
Es lädt die Wahllokal-Daten und vergleicht sie mit dem letzten abgelegten Stand - 
wenn sich nichts verändert hat, wird das Skript beendet. 

Mit den Daten aus den Wahllokalen wird zuerst das "Feldmann-o-meter" aktualisiert - 
die Grafik, die anzeigt, welcher Anteil der Wahlberechtigten schon ausgezählt ist, 
wieviele Ja- und Nein-Stimmen es gab, und welchen Anteil die Ja-Stimmen an der 
Gesamtheit der Wahlberechtigten hätten (geschätzt auf den Anteil der ausgezählten
Wahlberechtigten).

Dann wird aus den Wahllokal-Daten der Auszählung für den Stadtteil generiert - 
das kann man in dieser Form auch direkt vom Server der Stadt ziehen; da ich aber
die Zuordnung der Wahllokale zu den Stadtteilen habe und selbst aggregieren kann, 
rechnet eine Routine es schnell selbst. 

Aus der Stadtteil-Auszählung werden die drei Datawrapper-Grafiken auf den aktuellen
Stand gebracht: 
- eine Choropleth-Karte mit dem Anteil der Ja-Stimmen an der Wahlbevölkerung,
- eine Symbol-Karte mit den absoluten Ja-Stimmen nach Wahlbezirk, 
- eine Tabelle mit den Ergebnissen in barrierefreier Form. 


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
 
 - Sobald ein Wahllokal ausgezählt ist, wird eine "Schnellmeldung" erzeugt und werden die CSVs aktualisiert. 
 - Eine Schnellmeldung umfasst ein Wahllokal.
 - Nicht ausgezählte Wahllokale enthalten NA bei Wahlberechtigten/Wählern
 - Ortsteile haben, solang sie noch nicht ganz ausgezählt sind, fiktive Wahlberechtigten-Zahlen - die dann nur die Wahllokale abbilden, die bereits ausgezählt sind. (Beispiel: Ein Ortsteil hat 3000 Wahlberechtigte in 3 Wahllokal-Bezirken mit jeweils 1000 Wahlberechtigten - solange nur 2 ausgezählt sind, wird für den Ortsteil eine Wahlberechtigten-Anzahl von 2000 angezeigt.)
 - Briefwahl"lokale" - die Wahllokale mit den Nummern 9xx-xx - haben 0 Wahlberechtigte.  
 
**An dieser Stelle ein Dankeschön an das Wahlamt der Stadt Frankfurt, das trotz Zeitdrucks geduldig und kompetent Unterstützung geleistet hat.**
