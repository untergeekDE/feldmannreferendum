# analyse.R

endergebnis_df <- aggregiere_stadtteile_mit_briefwahl(stimmbezirke_df) %>% 
  mutate(wahlbeteiligung = stimmen / wahlberechtigt * 100, 
         briefwahlquote = briefwahl /stimmen * 100, 
         jastimmenquote = ja / wahlberechtigt * 100)

write.xlsx(endergebnis_df,"daten/endergebnis.xlsx", overwrite = T)


wahllokale_final_df <- aggregiere_wahllokale(stimmbezirke_df) %>% 
  mutate(jastimmenquote = ja / wahlberechtigt * 100)

write.xlsx(wahllokale_final_df,"daten/wahllokale_final.xlsx", overwrite=T)

briefwahl_vs_wahllokal <- wahllokale_final_df %>% 
  group_by(typ) %>% 
  summarize(across(wahlberechtigt:nein, ~sum(.))) 

write.xlsx(briefwahl_vs_wahllokal,"daten/briefwahlauswertung.xlsx", overwrite=T)
