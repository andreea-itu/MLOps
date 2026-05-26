import logging
import os

import pandas as pd
import yaml

from pipelines.clean import Cleaner

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s:%(levelname)s:%(message)s"
)


def load_config():
    with open("config.yml", "r") as file:
        return yaml.safe_load(file)


def main():
    config = load_config()
    data = config["data"]

    train = pd.read_csv(data["raw_train_path"])
    test = pd.read_csv(data["raw_test_path"])

    cleaner = Cleaner()
    train_data = cleaner.clean_data(train)
    test_data = cleaner.clean_data(test)

    processed_train_path = data["processed_train_path"]
    processed_test_path = data["processed_test_path"]
    os.makedirs(os.path.dirname(processed_train_path), exist_ok=True)

    train_data.to_csv(processed_train_path, index=False)
    test_data.to_csv(processed_test_path, index=False)
    logging.info("Data cleaning completed successfully")


if __name__ == "__main__":
    main()
