# Projet Infrastructure Cloud : Team 8

Infrastructure AWS déployée avec **Terraform** : une application web hautement disponible, derrière un Load Balancer, avec **autoscaling** et **supervision CloudWatch**.

> Projet réalisé dans le cadre de la formation à Toulouse Ynov Campus.

## Architecture

```
                    Internet
                       │
               ┌───────▼────────┐
               │ Internet Gateway│
               └───────┬────────┘
                       │
        ┌──────────────▼──────────────┐
        │  ALB (HTTP :80) - public    │
        └──────┬───────────────┬──────┘
               │               │
   ┌───────────▼───┐   ┌───────▼───────┐
   │ Public 1      │   │ Public 2      │
   │ 10.8.1.0/24   │   │ 10.8.2.0/24   │
   │ (NAT Gateway) │   │               │
   └───────┬───────┘   └───────────────┘
           │ sortie Internet (NAT)
   ┌───────▼───────┐   ┌───────────────┐
   │ Private 1     │   │ Private 2     │
   │ 10.8.11.0/24  │   │ 10.8.12.0/24  │
   │ EC2 (ASG)     │   │ EC2 (ASG)     │
   └───────────────┘   └───────────────┘
      us-east-1a          us-east-1b
```

Le schéma réseau complet est disponible dans [`network-diagram.drawio`](./network-diagram.drawio) (à ouvrir avec [draw.io](https://app.diagrams.net)).

## Ressources déployées

| Composant | Détail |
|---|---|
| **VPC** | `10.8.0.0/16` (`LGZ-VPC1`) |
| **Subnets publics** | `10.8.1.0/24` (us-east-1a) et `10.8.2.0/24` (us-east-1b) |
| **Subnets privés** | `10.8.11.0/24` (us-east-1a) et `10.8.12.0/24` (us-east-1b) |
| **Internet Gateway** | Accès Internet pour les subnets publics |
| **NAT Gateway + Elastic IP** | Sortie Internet des instances privées (placée dans Public-Subnet-1) |
| **Application Load Balancer** | Public, listener HTTP :80 vers le Target Group |
| **Target Group** | Health check `GET /` toutes les 30 s (codes 200-399) |
| **Launch Template** | Amazon Linux 2023, `t2.micro`, disque 10 Go gp2 chiffré, clé `vockey` |
| **Auto Scaling Group** | min 1 / désiré 2 / max 5, réparti sur les 2 subnets privés, health check ELB |
| **Security Groups** | ALB : HTTP depuis Internet. EC2 : HTTP depuis l'ALB uniquement + SSH restreint à des IP autorisées |
| **CloudWatch** | 4 alarmes, 2 policies de scaling, 1 dashboard |

## Autoscaling et supervision

Les alarmes CloudWatch (période de 60 s, 3 évaluations) pilotent le dimensionnement du groupe :

| Alarme | Condition | Action |
|---|---|---|
| `LGZ-ALB-HighTraffic` | > 100 requêtes / instance | **+1 instance** (cooldown 60 s) |
| `LGZ-ALB-LowTraffic` | < 10 requêtes / instance | **-1 instance** (cooldown 60 s) |
| `LGZ-CPU-High` | CPU moyen > 70 % | Visible dans le dashboard |
| `LGZ-CPU-Low` | CPU moyen < 20 % | Visible dans le dashboard |

Le dashboard **`LGZ-Infrastructure-Dashboard`** regroupe l'état des alarmes, l'utilisation CPU et les métriques réseau (in/out, paquets) du groupe.

## Application web

Au démarrage, chaque instance exécute [`instance_config.sh`](./instance_config.sh) (via `user_data`) qui :

1. met à jour le système et installe **Apache (httpd)** + `mod_cgi` ;
2. génère une page web affichant l'**ID de l'instance** (récupéré via IMDSv2) et l'**heure de démarrage** ;
3. applique un style CSS simple.

En rafraîchissant la page via l'ALB, l'ID change : on voit donc le load balancing entre les instances.

## Structure du dépôt

```
.
├── main.tf                # VPC, subnets, routage, NAT, Launch Template, ALB, listener
├── groups.tf              # Security Groups, Target Group, Auto Scaling Group
├── alertes.tf             # Alarmes CloudWatch, policies de scaling, dashboard
├── provider.tf            # Provider AWS et versions
├── instance_config.sh     # Script user_data (Apache + page web)
├── network-diagram.drawio # Schéma réseau
└── Images/                # Captures d'écran
```

## Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.2`
- [AWS CLI](https://docs.aws.amazon.com/cli/) configuré avec un profil `default` (région `us-east-1`)
- Une paire de clés EC2 nommée **`vockey`** existante dans la région
- Les droits pour créer VPC, EC2, ELB, Auto Scaling et CloudWatch

## Déploiement

```bash
# 1. Cloner le dépôt
git clone https://github.com/LuisGP-sudo/team-8-projet-infracloud.git
cd team-8-projet-infracloud

# 2. Initialiser Terraform
terraform init

# 3. Vérifier le plan
terraform plan

# 4. Déployer
terraform apply
```

Une fois le déploiement terminé, récupérer le DNS du Load Balancer (console AWS > EC2 > Load Balancers > `lgz-loadbalancer`) et l'ouvrir dans un navigateur :

```
http://<dns-de-l-alb>
```

> Les instances mettent quelques minutes à passer en `healthy` après le démarrage.

## Tester l'autoscaling

Générer de la charge sur l'ALB, par exemple avec `hey` ou `ab` :

```bash
ab -n 20000 -c 50 http://<dns-de-l-alb>/
```

Vérifier ensuite dans la console (Auto Scaling > `LGZ-AutoscalingGroup` et le dashboard CloudWatch) que le nombre d'instances augmente, puis redescend quand le trafic s'arrête.

## Nettoyage

```bash
terraform destroy
```

## Équipe

**Team 8**

- Luis G.P. ([@LuisGP-sudo](https://github.com/LuisGP-sudo))
