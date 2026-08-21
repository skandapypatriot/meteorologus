import pickle
import numpy as np

# 1. Class definition for unpickling
class KNRSameDayPredictor:
    def __init__(self, model, scaler, feature_names):
        self.model, self.scaler, self.feature_names = model, scaler, feature_names

print("Loading KNN model from pkl...")
with open("servermodels/weather_model_same_day.pkl", "rb") as f:
    predictor_obj = pickle.load(f)["predict"]

knn_model = predictor_obj.model
scaler = predictor_obj.scaler

# Extract the stored dataset inside KNN
X_train = knn_model._fit_X  # Features matrix
y_train = knn_model._y      # Target values array
n_neighbors = knn_model.n_neighbors

num_samples, num_features = X_train.shape

print(f"KNN parameters: N_SAMPLES={num_samples}, NUM_FEATURES={num_features}, K={n_neighbors}")

# Generate C header file containing the dataset and distance search
c_code = f"""#ifndef WEATHER_MODEL_SAME_H
#define WEATHER_MODEL_SAME_H

#include <math.h>

#define KNN_N_SAMPLES {num_samples}
#define KNN_N_FEATURES {num_features}
#define KNN_K {n_neighbors}

// Stored training feature vectors
static const double KNN_X[{num_samples}][{num_features}] = {{
"""

for row in X_train:
    c_code += "    {" + ", ".join([str(val) for val in row]) + "},\n"

c_code += "};\n\n// Stored target values\nstatic const double KNN_Y[" + str(num_samples) + "] = {\n"
c_code += "    " + ", ".join([str(val) for val in y_train]) + "\n};\n\n"

c_code += """
// Custom C++ KNN Prediction Function
inline double score_same_day(const double* input) {
    double distances[KNN_N_SAMPLES];
    int indices[KNN_N_SAMPx LES];

    // 1. Compute Euclidean distances to all stored samples
    for (int i = 0; i < KNN_N_SAMPLES; i++) {
        double dist_sq = 0.0;
        for (int j = 0; j < KNN_N_FEATURES; j++) {
            double diff = input[j] - KNN_X[i][j];
            dist_sq += diff * diff;
        }
        distances[i] = dist_sq; // Using squared distance to avoid expensive sqrt()
        indices[i] = i;
    }

    // 2. Simple selection sort to find top K smallest distances
    for (int i = 0; i < KNN_K; i++) {
        int min_idx = i;
        for (int j = i + 1; j < KNN_N_SAMPLES; j++) {
            if (distances[j] < distances[min_idx]) {
                min_idx = j;
            }
        }
        // Swap distance
        double temp_d = distances[i];
        distances[i] = distances[min_idx];
        distances[min_idx] = temp_d;

        // Swap index
        int temp_idx = indices[i];
        indices[i] = indices[min_idx];
        indices[min_idx] = temp_idx;
    }

    // 3. Average the target values of the K nearest neighbors
    double sum = 0.0;
    for (int i = 0; i < KNN_K; i++) {
        sum += KNN_Y[indices[i]];
    }

    return sum / (double)KNN_K;
}

#endif // WEATHER_MODEL_SAME_H
"""

with open("weather_model_same.h", "w") as f:
    f.write(c_code)

print("Successfully generated KNN weather_model_same.h!")