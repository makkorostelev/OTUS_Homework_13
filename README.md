# OTUS_Homework_13
 
Project creates one YC LB, 2 nginx proxy server, 2 nginx+php-fpm+wordpress backends, pxc cluster+proxysql(3 servers) and Hashicorp Vault server.
### Project Scheme
![Project Scheme](https://github.com/makkorostelev/OTUS_Homework_13/blob/main/Screenshots/scheme.png)


### Prerequisite

- **Ansible 2.9+**
- **hvac 2.1.0+**

To work with the project you need to write your data into variables.tf.\
![Variables](https://github.com/makkorostelev/OTUS_Homework_13/blob/main/Screenshots/variables.png)\
Then enter the commands:\
`terraform init`\
`terraform apply`

After ~5 minutes project will be initialized and run:\
Below there is an example of successful set up:

```
Apply complete! Resources: 24 added, 0 changed, 0 destroyed.

Outputs:

admin_ip = "158.160.55.20"
backend_ips = [
  "10.5.0.18",
  "10.5.0.7",
]
database_ips = [
  "10.5.0.20",
  "10.5.0.36",
  "10.5.0.16",
]
lb_ip = "51.250.80.28"
nginx_ips = [
  "10.5.0.5",
  "10.5.0.35",
]
vault_ip = "158.160.42.185"
```
Then go to vault addr by the command:\
`ssh ubuntu@vault_ip`

Then enter the command:\
`vault operator init`\
Below is an example output:
```
ubuntu@vault:~$ vault operator init
Recovery Key 1: d3RSL+BWeJzmYNXDJB0ROKBsiv5dDv29fAZBdhgr/msH
Recovery Key 2: 4NTPLR1UpvpuVRf2dDazbTMqY+FG6KTvT3VIcLEGs8oz
Recovery Key 3: 0e3BO1YOesfOBgySni8hzS4Et0MdSw1anWQCiyDrbAk2
Recovery Key 4: N7o0+CEsrGEX0OvAXR1eo1Ww0PdJGD/xe5+omyQXZriU
Recovery Key 5: 9GfGCDIYx0yfzgvlQbfeFm3KpVdxnds9e+XfTtZfW3Rv

Initial Root Token: hvs.Uvux1nNPcXQYDmBOY4rOQlDu

Success! Vault is initialized

Recovery key initialized with 5 key shares and a key threshold of 3. Please
securely distribute the key shares printed above.
```

Now you know your Initial Root Token and can login on Hashicorp Vault instance(https://vault_ip:8200) and configure it to manage your passwords.\
![Vault](https://github.com/makkorostelev/OTUS_Homework_13/blob/main/Screenshots/vault.png)

You can go to http://lb_ip and add your wordpress template to that installation :\
![Wordpress](https://github.com/makkorostelev/OTUS_Homework_13/blob/main/Screenshots/wordpress.png)
Even if one of nginx or pxc servers will be shutdown everything will work as it should
