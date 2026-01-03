## 🚀 Quick Start (Developers)

```bash
# Clone the repo
git clone https://github.com/robtdavis/trailforge-oss.git 
cd trailforge-oss

# Authorize an org
sf org login web --set-default -a trailforge-dev

# Deploy metadata
sf project deploy start

# Prepare and load demo content
node data/remove-autonumber-fields.js
sf data import tree -p data/trailforge-seed-plan.json

# Open TrailForge
sf org open

``` 