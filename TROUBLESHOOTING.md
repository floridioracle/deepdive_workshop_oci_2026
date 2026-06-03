# Troubleshooting · DeepDive Workshop OCI 2026

Esta guia cubre problemas comunes al iniciar los notebooks en AIDP.

## 1) Error de esquema en Spark/AIDP

### Sintoma

Al ejecutar una lectura como:

```python
bronze_df = spark.table("deepdivecatalog_bronze.admin.bronze_wc_matches")
```

aparece un error similar a:

`AnalysisException: [SCHEMA_NOT_FOUND] The schema "admin" cannot be found`

### Causa mas comun

El catalogo externo esta resolviendo el esquema en `ORACLELABS` y no en `ADMIN`.

### Solucion recomendada

1. Abre el script [tools/sqltools_oracle_schema_setup.sql](./tools/sqltools_oracle_schema_setup.sql).
2. Entra a tu instancia de **Autonomous Database** en OCI.
3. Abre **Database Actions**.
4. Ingresa a **SQL** para abrir **SQL Web**.
5. Verifica que la sesion este conectada con el usuario `ADMIN`.
6. Ejecuta todo el script como `ADMIN`.
7. El script:
- crea/habilita el usuario `ORACLELABS`
- crea y carga `ORACLELABS.BRONZE_WC_MATCHES`
- replica la tabla en `ADMIN.BRONZE_WC_MATCHES`
- habilita ORDS REST para el esquema y la tabla
- imprime URLs REST de referencia al final
8. En notebooks, usa `oraclelabs` en el path del catalogo:

```python
bronze_df = spark.table("deepdivecatalog_bronze.oraclelabs.bronze_wc_matches")
display(bronze_df.limit(5))
```

### Opcion robusta (fallback admin -> oraclelabs)

```python
schema_ok = None

for schema in ["admin", "oraclelabs"]:
    try:
        bronze_df = spark.table(f"deepdivecatalog_bronze.{schema}.bronze_wc_matches")
        schema_ok = schema
        break
    except Exception:
        pass

if schema_ok is None:
    raise Exception("No se encontro la tabla en admin ni oraclelabs")

print(f"Esquema usado: {schema_ok}")
display(bronze_df.limit(5))
```

## 2) Datos cargados pero no visibles

### Sintoma

La tabla existe pero `COUNT(*)` devuelve `0` o AIDP no la ve.

### Solucion

Despues de `DBMS_CLOUD.COPY_DATA`, ejecuta:

```sql
/
COMMIT;
```

Verifica luego:

```sql
SELECT COUNT(*) AS total_oraclelabs
FROM ORACLELABS.BRONZE_WC_MATCHES;

SELECT COUNT(*) AS total_admin
FROM ADMIN.BRONZE_WC_MATCHES;
```

## 3) Error instalando paquetes en notebook

### Sintoma

Comando `%pip` invalido al usar comas.

### Sintaxis correcta

Usa una celda solo con:

```python
%pip install scikit-learn matplotlib seaborn
```

Sin comas y sin mezclar con otras lineas de Python en la misma celda.
