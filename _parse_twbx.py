import zipfile
import os

twbx_path = r'C:\Users\ytaketani\OneDrive - Tampa Bay Rays Baseball Ltd\Strategy & Analytics - Analytics\Dashboards\Tableau Cloud\2026\Ticketing\2026 CRM Dashboards.twbx'

z = zipfile.ZipFile(twbx_path)
print("=== Files in .twbx ===")
for name in z.namelist():
    print(name)

# Extract the .twb file
for name in z.namelist():
    if name.endswith('.twb'):
        print(f"\nExtracting: {name}")
        z.extract(name, r'C:\Users\ytaketani\Rays-CRM-Agent\_tableau_temp')
        print(f"Extracted to: C:\\Users\\ytaketani\\Rays-CRM-Agent\\_tableau_temp\\{name}")
        break

z.close()
