import logging
import os

from pipelines.ingest import Ingestion

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s:%(levelname)s:%(message)s"
)


def main():
    ingestion = Ingestion()
    config = ingestion.config
    train, test = ingestion.load_data()

    raw_train_path = config["data"]["raw_train_path"]
    raw_test_path = config["data"]["raw_test_path"]
    os.makedirs(os.path.dirname(raw_train_path), exist_ok=True)

    train.to_csv(raw_train_path, index=False)
    test.to_csv(raw_test_path, index=False)
    logging.info("Data ingestion completed successfully")


if __name__ == "__main__":
    main()
