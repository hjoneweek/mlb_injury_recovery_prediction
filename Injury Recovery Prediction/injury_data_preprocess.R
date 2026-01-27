pacman::p_load(tidyverse)


load_data <- function(file_name) {
  file_name %>%
    read.csv(fileEncoding = "UTF-8") %>%
    as_tibble()
}

load_data('./data/Injury Records(2020).csv') -> injury_records_2020
load_data('./data/Injury Records(2021).csv') -> injury_records_2021
load_data('./data/Injury Records(2022).csv') -> injury_records_2022
load_data('./data/Injury Records(2023).csv') -> injury_records_2023
load_data('./data/Injury Records(2024).csv') -> injury_records_2024
load_data('./data/Injury Records(2025).csv') -> injury_records_2025

bind_rows(injury_records_2025,
          injury_records_2024,
          injury_records_2023,
          injury_records_2022,
          injury_records_2021,
          injury_records_2020) -> combined_injury_records

colnames(combined_injury_records) <- c('name', 
                                       'team',
                                       'pos',
                                       'date_injury',
                                       'injury',
                                       'status',
                                       'date_il_retro',
                                       'eligible_return',
                                       'date_return',
                                       'latest_update')

pacman::p_load(lubridate)

# Standardize the form of date_injury into MM/DD/YYYY
combined_injury_records %>%
  mutate(date_injury = parse_date_time(date_injury, order = c("mdy", "by")),
         date_injury = format(date_injury, "%m-%d-%Y"),
         date_injury = mdy(date_injury),
         date_il_retro = mdy(gsub('/', '-', date_il_retro)),
         eligible_return = mdy(gsub('/', '-', eligible_return)),
         date_return = mdy(gsub('/', '-', date_return))) -> combined_injury_records

combined_injury_records %>% glimpse()

# Calculate the duration of the injury
combined_injury_records %>%
  mutate(days_injured = ifelse(date_injury < date_il_retro,
                               date_injury %--% date_return %>% as.duration() / ddays(1),
                               date_il_retro %--% date_return %>% as.duration() / ddays(1)))  -> combined_injury_records


# Filter undisclosed injuries, days injured less than 0
combined_injury_records %>%
  filter(injury != 'Undisclosed') %>%
  filter(days_injured > 0) %>%
  select(name, team, pos, date_injury, injury, date_il_retro, date_return, days_injured)-> combined_injury_records

combined_injury_records %>%
  mutate(pos = fct_collapse(
    pos,
    P = c('SP', 'RP', 'RP/SP', 'SP/RP'),
    C = 'C',
    INF = c('1B', '2B', '3B', '1B/3B', '3B/1B', 'SS'),
    OF = c('OF', 'Of'),
    UTL = c('UTL', 'INF', 'INF/OF', '1B/OF', 'OF/1B', '2B/OF', '3B/OF', 'C/OF', 'C/1B', '1B/OF', 'OF/INF'),
    DH = 'DH'
  )) -> combined_injury_records

fct_count(combined_injury_records$pos)

combined_injury_records %>%
  mutate(injury_category = case_when(days_injured < 30 ~ 'mild',
                                         days_injured < 100 ~ 'moderate',
                                         days_injured < 180 ~ 'severe',
                                         TRUE ~ 'season-out')) -> combined_injury_records


load_data('Data/People.csv') -> players

players %>%
  glimpse()

players %>%
  mutate(debut = ymd(debut),
         finalGame = ymd(finalGame),
         date_of_birth = ymd(paste0(birthYear, "-", birthMonth, "-", birthDay))) -> players

players %>% glimpse()

players %>%
  select(nameFirst, nameLast, nameGiven, date_of_birth, debut, finalGame) -> players_important_dates

players_important_dates %>%
  drop_na(debut) %>%
  replace_na(list(finalGame = today())) %>%
  filter(finalGame > ymd(20200101)) %>%
  mutate(fullName = paste0(nameFirst, " ", nameLast),
         idName = gsub('á','a', fullName),
         idName = gsub('é','e', idName),
         idName = gsub('í','i', idName),
         idName = gsub('ó','o', idName),
         idName = gsub('ú','u', idName),
         idName = gsub('ñ','n', idName),
         idName = gsub('Jr.', '', idName),
         idName = gsub('-', '', idName),
         idName = gsub(' ', '', idName)) -> players_important_dates

combined_injury_records %>%
  mutate(idName = gsub('á','a', name),
         idName = gsub('é','e', idName),
         idName = gsub('í','i', idName),
         idName = gsub('ó','o', idName),
         idName = gsub('ú','u', idName),
         idName = gsub('ñ','n', idName),
         idName = gsub('Jr.', '', idName),
         idName = gsub(' ', '', idName),
         idName = gsub('-', '', idName)) -> combined_injury_records

left_join(combined_injury_records, players_important_dates %>% select(date_of_birth, idName)) -> combined_injury_records

combined_injury_records %>%
  drop_na(date_of_birth) %>%
  select(name, date_of_birth, pos, injury, date_injury, date_il_retro, date_return, days_injured, injury_category) %>%
  mutate(age_at_injury = ifelse(date_injury < date_il_retro,
                                trunc(time_length(interval(date_of_birth, date_injury), 'year')),
                                trunc(time_length(interval(date_of_birth, date_il_retro), 'year')))) -> combined_injury_records

combined_injury_records %>%
  write.csv('./data/combined_injury_records.csv', row.names = FALSE)

combined_injury_records %>%
  select(injury) %>%
  unique() -> injuries

load_data('./Data/combined_injury_records_categorized.csv') -> categorized_injury_records

categorized_injury_records %>%
  select(injury, injury_type, body_part) -> categorized_injury_records

combined_injury_records %>%
  group_by(body_part, injury_type) %>%
  ggplot(aes(x))
         