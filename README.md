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

### a screenshot of the supervised machine learning output from the logistic regression procedure is here.
![proc_logistic.JPG](/proc_logistic.JPG)

## Second Week
#### Description of the data exploration phase of the project
In this phase, I loaded my key datasets into Power BI Desktop and created a number of visualizations to look for potential sources of bias in my conclusions.  I had trouble getting all the data I wanted in the proper form.

The visualizations were based on the number of procedures in the database that stroke patients had in 2017.  Although the data is very granular, the location of hospitals is only given as one of the nine U.S. Census Divisions.  Other hospital descriptors include urban vs. rural, teaching hospital (yes or no), and size (number of beds).

There is a chloropleth map in the report that feeds into the dashboard.  The U.S. Census has shapefiles on the website, including one for the U.S. Census Divisions.  That zipfile was uploaded to map___ and converted into a topoJSON file.  Unfortunately, the visualization had too much data to pin to the dashboard.  I was not able to get this to work.

#### Description of the analysis phase of the project Slides 
Selecting which pieces of the analysis to include in the data story has been challenging.  The first draft of the dashboard is here.  

For the machine learning part of the project, I decided to use supervised machine learning.  I selected logistic regression to identify the best method for identifying the devices I was looking for.  I used an exact match of SKU numbers and a regular expression match on the variable hosp_chg_desc, and then a subset on the variable std_chg_desc of "MICROCATHETERS".  This third method came about a bit by accident.  Other devices have not been so well-specified in the charge description fields.  When available, this will be the best method for a first pass of identifying devices; the other two devices will be more useful within that subset.


![final_dashboard.JPG](/final_dashboard.JPG)

#### Presentation is in Power Point, and can be found here.
![Visualizing_RWD.pptx](/Visualizing_RWD.pptx)