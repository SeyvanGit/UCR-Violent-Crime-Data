# install.packages

library(httr)
library(jsonlite)
library(dplyr)
library(purrr)
library(readr)
library(tidyr)


API_KEY <- "XXXXX"   ## Get the API from https://api.data.gov/signup/
BASE    <- "https://api.usa.gov/crime/fbi/cde"
FROM    <- "01-2018"   # MM-YYYY
TO      <- "12-2024"
KEEP_ONLY_ACTUAL <- FALSE

# ---- All available FBI UCR offense codes from API ----
offenses <- c("V",    # Violent crime
              "ASS",  # Aggravated assault
              "BUR",  # Burglary
              "LAR",  # Larceny-theft
              "MVT",  # Motor vehicle theft
              "HOM",  # Murder and nonnegligent manslaughter
              "RPE",  # Rape
              "ROB",  # Robbery
              "ARS",  # Arson
              "P")    # Property crime

offense_names <- c(
  V    = "Violent crime",
  ASS  = "Aggravated assault",
  BUR  = "Burglary",
  LAR  = "Larceny-theft",
  MVT  = "Motor vehicle theft",
  HOM  = "Murder and nonnegligent manslaughter",
  RPE  = "Rape",
  ROB  = "Robbery",
  ARS  = "Arson",
  P    = "Property crime"
)

# 50 states (add DC if needed)
state_names <- c(
  AL="Alabama", AK="Alaska", AZ="Arizona", AR="Arkansas", CA="California", CO="Colorado",
  CT="Connecticut", DE="Delaware", FL="Florida", GA="Georgia", HI="Hawaii", ID="Idaho",
  IL="Illinois", IN="Indiana", IA="Iowa", KS="Kansas", KY="Kentucky", LA="Louisiana",
  ME="Maine", MD="Maryland", MA="Massachusetts", MI="Michigan", MN="Minnesota",
  MS="Mississippi", MO="Missouri", MT="Montana", NE="Nebraska", NV="Nevada",
  NH="New Hampshire", NJ="New Jersey", NM="New Mexico", NY="New York",
  NC="North Carolina", ND="North Dakota", OH="Ohio", OK="Oklahoma", OR="Oregon",
  PA="Pennsylvania", RI="Rhode Island", SC="South Carolina", SD="South Dakota",
  TN="Tennessee", TX="Texas", UT="Utah", VT="Vermont", VA="Virginia",
  WA="Washington", WV="West Virginia", WI="Wisconsin", WY="Wyoming"
)
states <- names(state_names)

`%||%` <- function(x, y) if (is.null(x)) y else x

safe_num <- function(x) {
  if (is.null(x) || length(x) == 0) return(setNames(numeric(0), character(0)))
  v <- as.numeric(suppressWarnings(unlist(x)))
  names(v) <- names(x)
  v
}

pick_state_key <- function(out, st_abbr) {
  want <- state_names[[st_abbr]]
  keys_actual <- names(out$offenses$actuals %||% list())
  keys_rates  <- names(out$offenses$rates   %||% list())
  keys_any    <- unique(c(keys_actual, keys_rates))
  
  if (!is.null(want) && length(keys_any) && want %in% keys_any) {
    return(want)
  }
  if (!is.null(want) && length(keys_any)) {
    m <- which(tolower(keys_any) == tolower(want))
    if (length(m) == 1) return(keys_any[m])
  }
  if (length(keys_any) == 1) {
    warning(sprintf("API returned '%s' for %s; using it (verify).", keys_any[1], st_abbr))
    return(keys_any[1])
  }
  warning(sprintf("No matching state key for %s (%s).", st_abbr, want))
  return(NA_character_)
}

fetch_monthly_state <- function(st, off_code) {
  suppressWarnings({
    url <- sprintf("%s/summarized/state/%s/%s?from=%s&to=%s&API_KEY=%s",
                   BASE, st, off_code, FROM, TO, API_KEY)
    r <- GET(url, user_agent("R-fbi-cde-multi-offense"))
    if (http_error(r)) {
      warning(sprintf("HTTP %s for %s/%s", status_code(r), st, off_code))
      return(tibble())
    }
    out <- fromJSON(content(r, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
    
    st_key <- pick_state_key(out, st)
    if (is.na(st_key)) return(tibble())
    
    actuals <- tryCatch(out$offenses$actuals[[st_key]], error = function(e) NULL)
    rates   <- tryCatch(out$offenses$rates[[st_key]],   error = function(e) NULL)
    pop_obj <- tryCatch(out$populations$population,     error = function(e) NULL)
    
    months <- union(names(actuals %||% list()),
                    union(names(rates %||% list()), names(pop_obj %||% list())))
    if (length(months) == 0) return(tibble())
    
    act_vec  <- safe_num(actuals);  act_vec  <- act_vec[months]
    rate_vec <- safe_num(rates);    rate_vec <- rate_vec[months]
    
    if (!is.null(pop_obj)) {
      pop_vec <- safe_num(pop_obj)
      if (!is.null(names(pop_vec)) && all(months %in% names(pop_vec))) {
        pop_vec <- pop_vec[months]
      } else if (length(pop_vec) == length(months)) {
        names(pop_vec) <- months
      } else {
        pop_vec <- setNames(rep(NA_real_, length(months)), months)
      }
    } else {
      pop_vec <- setNames(rep(NA_real_, length(months)), months)
    }
    
    month_count <- ifelse(!is.na(act_vec), act_vec,
                          ifelse(!is.na(rate_vec) & !is.na(pop_vec),
                                 round(rate_vec * pop_vec / 100000),
                                 NA_real_))
    source_type <- ifelse(!is.na(act_vec), "actual",
                          ifelse(!is.na(rate_vec) & !is.na(pop_vec), "estimated", NA))
    
    tibble(
      state_abbr = st,
      offense_code = off_code,
      offense_name = offense_names[off_code] %||% off_code,
      month = months,
      year  = as.integer(sub(".*-", "", months)),
      month_count = month_count,
      month_rate_per_100k = rate_vec,
      source_type = source_type
    ) %>%
      filter(!is.na(source_type))
  })
}

# ---- Fetch monthly for states ----
monthly <- tidyr::crossing(state = states, offense = offenses) %>%
  mutate(data = map2(state, offense, fetch_monthly_state)) %>%
  tidyr::unnest(data, keep_empty = FALSE)

if (nrow(monthly) == 0) stop("No rows returned. Check API key/date range.")

# ---- Aggregate yearly ----
yearly <- monthly %>%
  group_by(state_abbr, offense_code, offense_name, year) %>%
  summarise(
    offense_count = sum(month_count, na.rm = TRUE),
    offense_rate_per_100k_avg = mean(month_rate_per_100k, na.rm = TRUE),
    months_actual = sum(source_type == "actual", na.rm = TRUE),
    months_estimated = sum(source_type == "estimated", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(any_estimated = months_estimated > 0)

if (KEEP_ONLY_ACTUAL) {
  yearly <- yearly %>% filter(!any_estimated)
}
# ---- Save outputs ----
write_csv(monthly, "ucr_offenses_2018_2024_by_state_monthly.csv")
write_csv(yearly,  "ucr_offenses_2018_2024_by_state_yearly.csv")

cat(
  "Saved:/n",
  "- ucr_offenses_2018_2024_by_state_monthly.csv (source_type per month)/n",
  "- ucr_offenses_2018_2024_by_state_yearly.csv (counts, avg rates, months_actual/estimated, any_estimated)/n"
)


#### END ##########