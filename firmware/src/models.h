#ifndef MODELS_H
#define MODELS_H

enum ForecastSource { FORECAST_LOCAL = 0, FORECAST_FIREBASE = 1 };

void run_local_prediction();
ForecastSource get_forecast_source();
void set_forecast_source(ForecastSource s);

#endif // MODELS_H
