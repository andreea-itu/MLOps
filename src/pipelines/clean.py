import numpy as np
from sklearn.impute import SimpleImputer


class Cleaner:
    def __init__(self):
        #  creates a missing-value filler and stores it on the Cleaner instance 
        # so clean_data can reuse it for Gender and RegionID.
        # strategy="most_frequent"  - the value that appears most often in the column. 
        # missing_values=np.nan     - Only treat NaN as missing. 
        self.imputer = SimpleImputer(strategy="most_frequent", missing_values=np.nan)

    def clean_data(self, data):
        # Drop unneeded columns.
        data.drop(
            ["id", "SalesChannelID", "VehicleAge", "DaysSinceCreated"],
            axis=1,
            inplace=True,
        )

        # Replace characters
        data["AnnualPremium"] = (
            data["AnnualPremium"]
            .str.replace("£", "")
            .str.replace(",", "")
            .astype(float)
        )

        #  if many rows have missing Gender, they all get the most common gender in that dataset
        # Same idea for RegionID with the most common region id
        for col in ["Gender", "RegionID"]:
            data[col] = self.imputer.fit_transform(data[[col]]).flatten()

        # Fill in data with the median
        data["Age"] = data["Age"].fillna(data["Age"].median())

        data["HasDrivingLicense"] = data["HasDrivingLicense"].fillna(1)
        data["Switch"] = data["Switch"].fillna(-1)
        data["PastAccident"] = data["PastAccident"].fillna("Unknown", inplace=False)

        # Remove outliers
        Q1 = data["AnnualPremium"].quantile(0.25)
        Q3 = data["AnnualPremium"].quantile(0.75)
        # Calculate the IQR
        IQR = Q3 - Q1
        upper_bound = Q3 + 1.5 * IQR
        data = data[data["AnnualPremium"] <= upper_bound]

        return data
