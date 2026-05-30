"""Build, train, and persist the insurance classification sklearn pipeline."""

import os
import joblib
from utils.helper import load_config
from sklearn.preprocessing import StandardScaler, OneHotEncoder, MinMaxScaler
from sklearn.compose import ColumnTransformer
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.tree import DecisionTreeClassifier


class Trainer:
    """Train a classifier with preprocessing,
    oversampling with SMOTE, and config-driven hyperparameters."""

    def __init__(self):
        self.config = load_config()
        self.model_name = self.config["model"]["name"]
        self.model_params = self.config["model"]["params"]
        self.model_path = self.config["model"]["store_path"]
        self.pipeline = self.create_pipeline()

    def create_pipeline(self):
        """Assemble preprocessing, oversampling, and the classifier from config.yml."""
        preprocessor = ColumnTransformer(
            transformers=[
                ("minmax", MinMaxScaler(), ["AnnualPremium"]),
                ("standardize", StandardScaler(), ["Age", "RegionID"]),
                (
                    "onehot",
                    OneHotEncoder(handle_unknown="ignore"),
                    ["Gender", "PastAccident"],
                ),
            ]
        )

        smote = SMOTE(sampling_strategy=1.0)

        model_map = {
            "RandomForestClassifier": RandomForestClassifier,
            "DecisionTreeClassifier": DecisionTreeClassifier,
            "GradientBoostingClassifier": GradientBoostingClassifier,
        }

        model_class = model_map[self.model_name]
        model = model_class(**self.model_params)

        pipeline = Pipeline(
            [("preprocessor", preprocessor), ("smote", smote), ("model", model)]
        )

        return pipeline

    def feature_target_separator(self, data):
        """Split cleaned DataFrame into features
        (all but last column) and target (last column)."""
        X = data.iloc[:, :-1]
        y = data.iloc[:, -1]
        return X, y

    def train_model(self, X_train, y_train):
        """Fit the full pipeline on training features and labels."""
        self.pipeline.fit(X_train, y_train)

    def save_model(self):
        """Write the fitted pipeline to {store_path}/model.pkl
        (used by predict and app)."""
        os.makedirs(self.model_path, exist_ok=True)
        model_file_path = os.path.join(self.model_path, "model.pkl")
        joblib.dump(self.pipeline, model_file_path)
