import os

import joblib
import yaml
from sklearn.preprocessing import StandardScaler, OneHotEncoder, MinMaxScaler
from sklearn.compose import ColumnTransformer
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline 
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.tree import DecisionTreeClassifier

class Trainer:
    def __init__(self):
        self.config = self.load_config()
        self.model_name = self.config['model']['name']
        self.model_params = self.config['model']['params']
        self.model_path = self.config['model']['store_path']
        self.pipeline = self.create_pipeline()

    def load_config(self):
        with open('config.yml', 'r') as config_file:
            return yaml.safe_load(config_file)
        
    def create_pipeline(self):
        preprocessor = ColumnTransformer(transformers=[
            ('minmax', MinMaxScaler(), ['AnnualPremium']),
            ('standardize', StandardScaler(), ['Age','RegionID']),
            ('onehot', OneHotEncoder(handle_unknown='ignore'), ['Gender', 'PastAccident']),
        ])
        
        smote = SMOTE(sampling_strategy=1.0)
        
        model_map = {
            'RandomForestClassifier': RandomForestClassifier,
            'DecisionTreeClassifier': DecisionTreeClassifier,
            'GradientBoostingClassifier': GradientBoostingClassifier
        }
    
        model_class = model_map[self.model_name]
        model = model_class(**self.model_params)

        pipeline = Pipeline([
            ('preprocessor', preprocessor),
            ('smote', smote),
            ('model', model)
        ])

        return pipeline

    def feature_target_separator(self, data):
        X = data.iloc[:, :-1]
        y = data.iloc[:, -1]
        return X, y

    def train_model(self, X_train, y_train):
        self.pipeline.fit(X_train, y_train)

    def save_model(self):
        os.makedirs(self.model_path, exist_ok=True)
        model_file_path = os.path.join(self.model_path, "model.pkl")
        joblib.dump(self.pipeline, model_file_path)
        self._register_with_mlflow()

    def _register_with_mlflow(self):
        tracking_uri = os.environ.get("MLFLOW_TRACKING_URI")
        if not tracking_uri:
            return

        import mlflow

        mlflow.set_tracking_uri(tracking_uri)
        registered_name = os.environ.get(
            "MLFLOW_REGISTERED_MODEL_NAME", "insurance-classifier"
        )
        run_name = os.environ.get("MLFLOW_RUN_NAME", "train")

        with mlflow.start_run(run_name=run_name):
            mlflow.log_param("model_name", self.model_name)
            for key, value in self.model_params.items():
                mlflow.log_param(key, value)
            mlflow.sklearn.log_model(
                self.pipeline,
                artifact_path="sklearn-model",
                registered_model_name=registered_name,
            )