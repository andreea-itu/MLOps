import pandas as pd
from utils.helper import load_config


class Ingestion:
    def __init__(self):
        self.config = load_config()

    def load_data(self):
        """Load the the train and test data."""
        train_data_path = self.config["data"]["train_path"]
        test_data_path = self.config["data"]["test_path"]
        train_data = pd.read_csv(train_data_path)
        test_data = pd.read_csv(test_data_path)
        return train_data, test_data
