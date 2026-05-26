import logging

import pandas as pd
import yaml

from pipelines.predict import Predictor
from pipelines.train import Trainer

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s:%(levelname)s:%(message)s"
)


def load_config():
    with open("config.yml", "r") as file:
        return yaml.safe_load(file)


def main():
    config = load_config()
    data = config["data"]

    train_data = pd.read_csv(data["processed_train_path"])
    test_data = pd.read_csv(data["processed_test_path"])

    trainer = Trainer()
    X_train, y_train = trainer.feature_target_separator(train_data)
    trainer.train_model(X_train, y_train)
    trainer.save_model()
    logging.info("Model training completed successfully")

    predictor = Predictor()
    X_test, y_test = predictor.feature_target_separator(test_data)
    accuracy, class_report, roc_auc_score = predictor.evaluate_model(X_test, y_test)
    logging.info("Model evaluation completed successfully")

    print("\n============= Model Evaluation Results ==============")
    print(f"Model: {trainer.model_name}")
    print(f"Accuracy Score: {accuracy:.4f}, ROC AUC Score: {roc_auc_score:.4f}")
    print(f"\n{class_report}")
    print("=====================================================\n")


if __name__ == "__main__":
    main()
