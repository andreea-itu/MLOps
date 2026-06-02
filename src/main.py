"""
End-to-end training: ingest → clean → train → evaluate, with MLflow tracking.

Run from the src directory:
  cd src && poetry run python main.py

If MLflow artifact logging fails after using a tracking server, reset local metadata:
  rm -rf mlruns
"""

import logging
import os
import tempfile
from pathlib import Path

import mlflow
import mlflow.sklearn
from pipelines.ingest import Ingestion
from pipelines.clean import Cleaner
from pipelines.train import Trainer
from pipelines.predict import Predictor
from sklearn.metrics import classification_report
from utils.helper import load_config


logging.basicConfig(level=logging.INFO, format="%(asctime)s:%(levelname)s:%(message)s")


def _set_experiment():
    """Pick a file-backed experiment when not using an MLflow tracking server."""
    name = "Model Training Experiment"
    uri = os.environ.get("MLFLOW_TRACKING_URI", "")
    if uri.startswith(("http://", "https://")):
        mlflow.set_tracking_uri(uri)
        mlflow.set_experiment(name)
        return
    mlruns = Path(__file__).resolve().parent / "mlruns"
    mlruns.mkdir(exist_ok=True)
    mlflow.set_tracking_uri(mlruns.as_uri())
    client = mlflow.tracking.MlflowClient()
    exp = client.get_experiment_by_name(name)
    if exp and exp.artifact_location.startswith("mlflow-artifacts:"):
        name = f"{name} (local)"
        if client.get_experiment_by_name(name) is None:
            client.create_experiment(name)
    mlflow.set_experiment(name)


def mlflow_main():
    config = load_config()

    _set_experiment()

    with mlflow.start_run() as run:
        # Load data
        ingestion = Ingestion()
        train, test = ingestion.load_data()
        logging.info("Data ingestion completed successfully")

        # Clean data
        cleaner = Cleaner()
        train_data = cleaner.clean_data(train)
        test_data = cleaner.clean_data(test)
        logging.info("Data cleaning completed successfully")

        # Prepare and train model
        trainer = Trainer()
        X_train, y_train = trainer.feature_target_separator(train_data)
        trainer.train_model(X_train, y_train)
        trainer.save_model()
        logging.info("Model training completed successfully")

        # Evaluate model
        predictor = Predictor()
        X_test, y_test = predictor.feature_target_separator(test_data)
        accuracy, class_report, roc_auc_score = predictor.evaluate_model(X_test, y_test)
        report = classification_report(
            y_test, trainer.pipeline.predict(X_test), output_dict=True
        )
        logging.info("Model evaluation completed successfully")

        # Tags
        mlflow.set_tag(
            "preprocessing", "OneHotEncoder, Standard Scaler, and MinMax Scaler"
        )

        # Inferring the input signature
        signature = mlflow.models.infer_signature(
            model_input=X_train, model_output=trainer.pipeline.predict(X_test)
        )

        # Log metrics
        model_params = config["model"]["params"]
        mlflow.log_params(model_params)
        mlflow.log_metric("accuracy", accuracy)
        mlflow.log_metric("roc", roc_auc_score)
        mlflow.log_metric("precision", report["weighted avg"]["precision"])
        mlflow.log_metric("recall", report["weighted avg"]["recall"])

        try:
            mlflow.sklearn.log_model(
                trainer.pipeline, artifact_path="model", signature=signature
            )
            model_name = "insurance_model"
            model_uri = f"runs:/{run.info.run_id}/model"
            if mlflow.get_tracking_uri().startswith(("http://", "https://")):
                mlflow.register_model(model_uri, model_name)
        except Exception as err:
            logging.warning(
                "MLflow model logging via API is unavailable; "
                "falling back to artifact-only logging. Error: %s",
                err,
            )
            with tempfile.TemporaryDirectory() as tmpdir:
                mlflow.sklearn.save_model(
                    trainer.pipeline, path=f"{tmpdir}/model", signature=signature
                )
                mlflow.log_artifacts(f"{tmpdir}/model", artifact_path="model")

        logging.info("MLflow tracking completed successfully")

        # Print evaluation results
        print("\n============= Model Evaluation Results ==============")
        print(f"Model: {trainer.model_name}")
        print(f"Accuracy Score: {accuracy:.4f}, ROC AUC Score: {roc_auc_score:.4f}")
        print(f"\n{class_report}")
        print("=====================================================\n")


if __name__ == "__main__":
    mlflow_main()
