"""Load the inference model from a local path or MLflow Model Registry."""

import os

import joblib


def _mlflow_model_uri() -> str:
    if uri := os.environ.get("MLFLOW_MODEL_URI"):
        return uri
    name = os.environ.get("MLFLOW_REGISTERED_MODEL_NAME", "insurance-classifier")
    stage = os.environ.get("MLFLOW_MODEL_STAGE", "Production")
    return f"models:/{name}/{stage}"


def use_mlflow_registry() -> bool:
    return bool(
        os.environ.get("MLFLOW_TRACKING_URI") or os.environ.get("MLFLOW_MODEL_URI")
    )


def load_inference_model():
    """
    Local dev: mount models/ and leave MLFLOW_* unset (loads models/model.pkl).
    Kubernetes: set MLFLOW_TRACKING_URI and registry name/stage (or MLFLOW_MODEL_URI).
    """
    if use_mlflow_registry():
        import mlflow

        tracking_uri = os.environ.get("MLFLOW_TRACKING_URI")
        if tracking_uri:
            mlflow.set_tracking_uri(tracking_uri)
        return mlflow.sklearn.load_model(_mlflow_model_uri())

    model_path = os.environ.get("MODEL_PATH", "models/model.pkl")
    return joblib.load(model_path)
