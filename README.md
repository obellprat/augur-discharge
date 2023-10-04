# augur-discharge
Augur-Shiny Web Application for river discharge calculations 

# Run Application
Copy Dockerfile above parent directory and build docker. 
```shell
sudo docker build -t augur-discharge .
sudo docker run -d --rm -p 3838:3838 augur-discharge
```
