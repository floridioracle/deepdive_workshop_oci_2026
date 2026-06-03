# DeepDive Terraform Setup

Este stack Terraform crea:

- Autonomous AI Database.
- AI Data Platform (AIDP).
- Wallet de Autonomous como output en base64 y, opcionalmente, como archivo zip local.
- Policy IAM requerida para que el servicio AIDP opere en el compartimento indicado.

## Region obligatoria

Este stack con AIDP debe desplegarse en OCI Chicago:

- Nombre de region: `US Midwest (Chicago)`
- Identificador de region: `us-chicago-1`

No desplegar este stack en Sao Paulo u otra region cuando AIDP este habilitado.

## Despliegue desde OCI Console / Resource Manager

El despliegue se hace creando un Stack con esta carpeta Terraform.

Pasos:

1. Entrar a OCI Console.
2. Ir a `Developer Services` -> `Resource Manager` -> `Stacks`.
3. Hacer click en `Create stack`.
4. En `Stack configuration`, elegir:
   - `My configuration`
   - `Upload folder` o `Upload zip file`
5. Subir esta carpeta/proyecto Terraform.



Variables minimas para el stack:

```hcl
compartment_id = "ocid1.compartment.oc1..your_compartment_ocid"
tenancy_ocid   = "ocid1.tenancy.oc1..your_tenancy_ocid"
region         = "us-chicago-1"

create_aidp        = true
create_aidp_policy = true
```

Si el stack se crea directamente en Chicago, `region` puede quedar vacio/null
para usar la region del stack. Para evitar dudas, se recomienda cargar
explicitamente `us-chicago-1`.

Despues de crear el stack:

1. Ejecutar `Plan`.
2. Revisar que el plan incluya Autonomous Database, AIDP, IAM policy y wallet.
3. Ejecutar `Apply`.

## Despliegue local con Terraform

Usar `terraform.tfvars` con Chicago:

```hcl
compartment_id = "ocid1.compartment.oc1..your_compartment_ocid"
tenancy_ocid   = "ocid1.tenancy.oc1..your_tenancy_ocid"
region         = "us-chicago-1"

create_aidp        = true
create_aidp_policy = true
```

Ejecutar desde la carpeta donde estan los `.tf`:

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Recursos principales

La base Autonomous queda fija con estos parametros en el codigo:

- `compute_model = "ECPU"`
- `compute_count = 2`
- `data_storage_size_in_gb = 100`
- `license_model = "LICENSE_INCLUDED"`
- `db_workload = "OLTP"`

## Policies IAM que crea el stack

Si `create_aidp = true` y `create_aidp_policy = true`, el stack crea una
policy IAM en el root tenancy usando `tenancy_ocid` como compartment de la
policy.

Nombre por defecto:

```hcl
aidp_policy_name = "DeepDiveAIDPServicePolicy"
```

Statements creados por la policy:

```text
allow any-user TO {AUTHENTICATION_INSPECT, DOMAIN_INSPECT, DOMAIN_READ, DYNAMIC_GROUP_INSPECT, GROUP_INSPECT, GROUP_MEMBERSHIP_INSPECT, USER_INSPECT, USER_READ} IN TENANCY where all {request.principal.type='aidataplatform'}

allow any-user to manage log-groups in compartment id <compartment_id> where ALL { request.principal.type='aidataplatform' }

allow any-user to read log-content in compartment id <compartment_id> where ALL { request.principal.type='aidataplatform' }

allow any-user to use metrics in compartment id <compartment_id> where ALL {request.principal.type='aidataplatform', target.metrics.namespace='oracle_aidataplatform'}

allow any-user to manage buckets in compartment id <compartment_id> where all { request.principal.type='aidataplatform', any {request.permission = 'BUCKET_CREATE', request.permission = 'BUCKET_INSPECT', request.permission = 'BUCKET_READ', request.permission = 'BUCKET_UPDATE'}}

allow any-user to {TAG_NAMESPACE_USE} in tenancy where all {request.principal.type = 'aidataplatform'}

allow any-user to manage buckets in compartment id <compartment_id> where all { request.principal.id=target.resource.tag.orcl-aidp.governingAidpId, any {request.permission = 'BUCKET_DELETE', request.permission = 'PAR_MANAGE', request.permission = 'RETENTION_RULE_LOCK', request.permission = 'RETENTION_RULE_MANAGE'} }

allow any-user to read objectstorage-namespaces in compartment id <compartment_id> where all { request.principal.type='aidataplatform', any {request.permission = 'OBJECTSTORAGE_NAMESPACE_READ'}}

allow any-user to manage objects in compartment id <compartment_id> where all { request.principal.id=target.bucket.system-tag.orcl-aidp.governingAidpId }
```

En el plan real, `<compartment_id>` se reemplaza por el OCID del compartimento
cargado en la variable `compartment_id`.

La identidad que ejecuta Resource Manager debe tener permiso para crear esta
policy en el root tenancy. Si la policy ya existe o se quiere crear manualmente,
usar:

```hcl
create_aidp_policy = false
```

## Outputs

- `autonomous_database_id`
- `autonomous_database_state`
- `aidp_id`
- `aidp_state`
- `aidp_policy_id`
- `wallet_base64` (sensitive)
- `admin_password` (sensitive, default: `Workshop@123`)
- `wallet_file_path` (cuando `write_wallet_file=true`)

Para leer outputs sensibles:

```bash
terraform output -raw admin_password
terraform output -raw wallet_base64
```

Para decodificar el wallet localmente:

```bash
terraform output -raw wallet_base64 > wallet.b64
base64 -d wallet.b64 > wallet.zip
```
