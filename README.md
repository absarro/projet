# PACT.Solutions.Postgres

*Installation et configuration d'un cluster Postgres avec PGPOOLII*

**POSTGRES**:
						-  Version 14 --> **DEFAULT**



**PGPOOL**:
						-  Version 4.5 --> **DEFAULT**

Cette installation de postgres permet d'instancier plusieurs Bases de Données.
Renseignez la variable postgres_bdd_liste dans votre fichier de conffiguration terraform
Les bases sont créer avec un user admin par defaut : admin_"nom_de_la_base"
Les mots de passes se trouvent dans votre espace VAULT

exemple: postgres_bdd_liste = ["bdd1", "bdd2", "bddn",...]