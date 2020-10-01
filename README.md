# final-project
#### ✓ Selected topic ✓ Reason why they selected their topic ✓ Description of their source of data ✓ Questions they hope to answer with the data

#### I will be evaluating the feasibility of using a U.S. hospital claims database for 2016-2019 to generate evidence to meet new regulatory requirements for medical device manufacturers. The new regulations cannot be fully met using traditional clinical trials and user surveys. I work at Stryker Neurovascular as a biostatistician, and my group is looking for a solution to this challenge.  

#### Stryker has purchased a one-year license to analyze the Premier Hospital Database, which includes about 1,000 hospitals and represents about 45% of U.S. hospital claims. Participating hospitals submit claims and medical record data to Premier on a monthly basis.  Premier then removes all of the PHI (Patient Health Information) and sells access to the anonymized data.  The data we need is in the billing records, which contain every item that a patient was charged for during a hospital stay.  However, the device information will have to be parsed from a text field that describes the item.

#### Some of the questions I hope to answer are:
    Can we extract enough detailed device data on our devices as well as competitor devices to do meaningful analyses?
    Can we identify patterns of device use in neurovascular procedures?
    Can we extract health outcomes data for patients who are treated with these devices?
    
#### The roadmap for the project is here:
    1. Access the data and create a description of the columns.
    2. Using multiple techniques, extract and classify the device information.
    3. Select a subset that has complete follow-up data.
    4. Create a procedure-level dataset with flag variables for every device.
    5. Use machine learning (k-means) to identify clusters of device use.
    6. Create a data visualization that enables patterns to be identified.
    7. Publish to a Power BI dashboard.

