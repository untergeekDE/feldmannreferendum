# feldmannreferendum

R-Routinen, um die Abstimmungsergebnisse des Referendums in Frankfurt am 6. November 2022 auf die hessenschau.de-Website zu bringen. 

V1.01 - Fragen und Anmerkungen jan.eggers (klammeraffe) hr.de

## Aufbau

- R - Programm- und Hilfscode
- index - Konfigurations- und Indexdateien z.B. mit den Stadtteilzuordnungen
- daten - Ausgabeordner für die aus dem Netz gelesenen und aufbereiteten Daten
- testdaten - Künstlich generierte Test-Dateien zur Simulation

### R-Dateien im Ordner R

- update_feldmann.R - Hauptskript
- lies_aktuellen_stand.R - Funktionen zur Datenakquise und -aufbereitung
- aktualisiere_karten.R - Update der Datawrapper-Karten und -Tabelle im Ortsteilergebnissen
- generiere_balken.R - Funktionen zur Generierung des HTML/CSS-Codes für die Datawrapper-Darstellungen
- messaging.R - Status- und Fehlermeldung über MS Teams
- generiere_testdaten.R - Zufällige Erzeugung von Simulationsdateien

- daten_vorbereiten.R - Hilfsskripte zur einmaligen Erzeugung der Index-Dateien

Das Skript **update_feldmann()** ist gewissermaßen das Hauptprogramm. Es ist dazu gedacht, 1x pro Minute aufgerufen zu werden. 
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

Durch Aufruf der Funktion **aktualisiere_karten()** werden die Ortsdaten erzeugt und für die Stadtteile in Datawrapper ausgegeben. Aus der Stadtteil-Auszählung werden die drei Datawrapper-Grafiken auf den aktuellen
Stand gebracht: 
- eine Choropleth-Karte mit dem Anteil der Ja-Stimmen an der Wahlbevölkerung,
- eine Symbol-Karte mit den absoluten Ja-Stimmen nach Ortsteil, 
- eine Tabelle mit den Ortsteil-Ergebnissen in barrierefreier Form. 

### index-Dateien

- config.csv enthält die URL, von der Daten gelesen werden, die Anzahl der Wahlberechtigten für Frankfurt (diese Zahl wird Sonntag 18 Uhr aktualisiert) und die IDs von Datawrapper-Zielen. 
- stadtteile-skaliert_08.geojson - Shapefile für die Datawrapper-Darstellungn der Ergebnisse
- stadtteile.csv - eine Datei mit den Namen der Ortsteile, Geokoordinaten mit einem Punkt, und den Wahlergebnissen des 1. Wahlgangs der Bürgermeisterwahl 2018 zum Vergleich
- zuordnung_wahllokale.csv - die Zuordnung der Wahllokale zu den Ortsteilen
- opendata-wahllokale.csv - Adressen der Wahllokale vom Wahlamt

## Datenquelle und Datenformat

Nutzt die Livedaten von https://wahlen.frankfurt.de - die aktuellen Daten nach Ortsteil und Stimmbezirk sind als CSV-Datei [auf dieser Seite zu finden](https://votemanager-ffm.ekom21cdn.de/2022-11-06/06412000/praesentation/opendata.html). Dort ist das Datenformat auch erklärt: 
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
 
Es gibt 575 Stimmbezirke - also administrative Auszählungs-Einheiten. Fast 200 von diesen "Bezirken" sind die Briefwahl-Auszählungen - sie werden alle in der Messe ausgezählt. Insgesamt gibt es 219 Wahllokale. (vgl. index/opendata-wahllokale.csv)

Eine kleine Falle wurde erst im Lauf des Wahlabends sichtbar: Die Briefwahl-Ergebnisse kommen systematisch später als alle anderen Ergebnisse - da ein Briefwahl-Stimmbezirk aber rechnerisch 0 Wahlberechtigte hat, kann man ohne die Briefwahl-Stimmen kein Quorum berechnen. Deshalb musste die Logik im Lauf des Abends von "% der Wahlberechtigten ausgezählt" auf "% der Wahllokale ausgezählt" umgestellt werden. 
 
## Wann gibt es wo Daten?
 
 - Sobald einer der 575 Stimmbezirke ausgezählt ist, wird eine "Schnellmeldung" erzeugt und werden die CSVs aktualisiert. 
 - Eine Schnellmeldung umfasst einen Stimmbezirk, ein Wahllokal idR mehrere davon.
 - Nicht ausgezählte Wahllokale enthalten NA bei Wahlberechtigten/Wählern
 - Ortsteile haben, solang sie noch nicht ganz ausgezählt sind, fiktive Wahlberechtigten-Zahlen - die dann nur die Wahllokale abbilden, die bereits ausgezählt sind. (Beispiel: Ein Ortsteil hat 3000 Wahlberechtigte in 3 Wahllokal-Bezirken mit jeweils 1000 Wahlberechtigten - solange nur 2 ausgezählt sind, wird für den Ortsteil eine Wahlberechtigten-Anzahl von 2000 angezeigt.)
 - Briefwahl"lokale" - die Stimmbezirke mit den Nummern 9xx-xx - haben 0 Wahlberechtigte.  
 
**An dieser Stelle ein Dankeschön an das Wahlamt der Stadt Frankfurt, das trotz Zeitdrucks geduldig und kompetent Unterstützung geleistet hat.**
