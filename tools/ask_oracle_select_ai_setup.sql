-- ================================================================
-- DeepDive Workshop OCI 2026
-- Ask Oracle / Select AI setup for:
--   - ORACLELABS.BRONZE_WC_MATCHES NL2SQL
--   - Combined vector index and RAG profile
-- ================================================================
-- Section A: run connected as ADMIN.
-- Sections B onward: reconnect as ORACLELABS after editing the defines.
-- ================================================================

set define on
set verify off
set serveroutput on

define ASK_ORACLE_USER = 'ORACLELABS'
define OCI_GENAI_REGION = 'us-chicago-1'
define OCI_GENAI_MODEL = 'xai.grok-4.3'
define OCI_GENAI_EMBED_MODEL = 'cohere.embed-multilingual-light-v3.0'
define OCI_COMPARTMENT_ID = 'ocid1.compartment.oc1..aaaaaaaaokqrjqnlqe7drotstyalyn55h2v72cftcjssj5wms5p5eiykgoya'
define CREDENTIAL_NAME = 'OCI$RESOURCE_PRINCIPAL'
define ASK_ORACLE_NL2SQL_PROFILE = 'DEEPDIVE_WC_NL2SQL'
define COMBINED_RAG_PROFILE = 'DEEPDIVE_WC_RAG'
define COMBINED_VECTOR_INDEX_NAME = 'DEEPDIVE_WC_COMBINED_IDX'
define COMBINED_VECTOR_TABLE_NAME = 'DEEPDIVE_WC_COMBINED_VECTAB'

-- Object Storage location used by the combined vector index.
-- Upload the RAG source documents/text files under this prefix before running section C.
define OBJECT_STORAGE_REGION = 'us-chicago-1'
define OBJECT_STORAGE_NAMESPACE = 'axihdaegan7g'
define SOURCE_BUCKET = 'demo_rag'
define COMBINED_RAG_PREFIX = 'ask-oracle-rag/combined'

define CHUNK_SIZE = 2048
define CHUNK_OVERLAP = 256
define REFRESH_RATE_MINUTES = 720
define MATCH_LIMIT = 10
define SIMILARITY_THRESHOLD = 0

define APEX_WORKSPACE = 'ASK_ORACLE'
define APEX_USER = 'ASK_ORACLE_ADMIN'

--------------------------------------------------------------------------------
-- A) ADMIN: minimum privileges for Select AI from the APEX parsing schema
--------------------------------------------------------------------------------

begin
  if sys_context('USERENV', 'SESSION_USER') <> 'ADMIN' then
    raise_application_error(-20000, 'Run section A connected as ADMIN.');
  end if;
end;
/

grant execute on dbms_cloud_ai to &&ASK_ORACLE_USER;
grant execute on dbms_cloud_ai_agent to &&ASK_ORACLE_USER;
grant execute on dbms_cloud_pipeline to &&ASK_ORACLE_USER;
grant execute on dbms_vector to &&ASK_ORACLE_USER;
grant execute on dbms_cloud to &&ASK_ORACLE_USER;
grant create any index to &&ASK_ORACLE_USER;

begin
  dbms_cloud_admin.enable_principal_auth(
    provider => 'OCI',
    username => upper('&&ASK_ORACLE_USER')
  );
exception
  when others then
    dbms_output.put_line('Resource principal enablement skipped or already enabled: ' || sqlerrm);
end;
/

prompt Section A complete. Reconnect as &&ASK_ORACLE_USER and run section B.

--------------------------------------------------------------------------------
-- B) ORACLELABS: NL2SQL profile over the workshop table
--------------------------------------------------------------------------------

begin
  if sys_context('USERENV', 'SESSION_USER') <> upper('&&ASK_ORACLE_USER') then
    raise_application_error(-20001, 'Run section B connected as &&ASK_ORACLE_USER.');
  end if;
end;
/

begin
  begin
    dbms_cloud_ai.drop_profile(profile_name => '&&ASK_ORACLE_NL2SQL_PROFILE');
  exception
    when others then
      null;
  end;

  dbms_cloud_ai.create_profile(
    profile_name => '&&ASK_ORACLE_NL2SQL_PROFILE',
    attributes => json_object(
      'provider'           value 'oci',
      'credential_name'    value '&&CREDENTIAL_NAME',
      'region'             value '&&OCI_GENAI_REGION',
      'model'              value '&&OCI_GENAI_MODEL',
      'embedding_model'    value '&&OCI_GENAI_EMBED_MODEL',
      'oci_compartment_id' value '&&OCI_COMPARTMENT_ID',
      'object_list'        value json_array(
        json_object('owner' value 'ORACLELABS', 'name' value 'BRONZE_WC_MATCHES')
      ),
      'conversation'       value 'true'
    ),
    status => 'enabled',
    description => 'DeepDive Ask Oracle NL2SQL and RAG profile'
  );
end;
/

--------------------------------------------------------------------------------
-- C) ORACLELABS: combined vector index over Object Storage documents
--------------------------------------------------------------------------------

begin
  if '&&OBJECT_STORAGE_NAMESPACE' = 'REPLACE_NAMESPACE'
     or '&&SOURCE_BUCKET' = 'REPLACE_BUCKET' then
    raise_application_error(
      -20002,
      'Edit OBJECT_STORAGE_NAMESPACE and SOURCE_BUCKET before running section C.'
    );
  end if;
end;
/

begin
  begin
    dbms_cloud_ai.drop_vector_index(
      index_name   => '&&COMBINED_VECTOR_INDEX_NAME',
      include_data => TRUE
    );
  exception
    when others then
      null;
  end;

  dbms_cloud_ai.create_vector_index(
    index_name => '&&COMBINED_VECTOR_INDEX_NAME',
    attributes => json_object(
      'vector_db_provider' value 'oracle',
      'vector_table_name' value '&&COMBINED_VECTOR_TABLE_NAME',
      'profile_name' value '&&ASK_ORACLE_NL2SQL_PROFILE',
      'location' value 'https://objectstorage.&&OBJECT_STORAGE_REGION.oraclecloud.com/n/&&OBJECT_STORAGE_NAMESPACE/b/&&SOURCE_BUCKET/o/&&COMBINED_RAG_PREFIX/',
      'object_storage_credential_name' value '&&CREDENTIAL_NAME',
      'chunk_size' value &&CHUNK_SIZE,
      'chunk_overlap' value &&CHUNK_OVERLAP,
      'refresh_rate' value &&REFRESH_RATE_MINUTES,
      'match_limit' value &&MATCH_LIMIT,
      'similarity_threshold' value &&SIMILARITY_THRESHOLD,
      'vector_distance_metric' value 'cosine'
    ),
    description => 'Combined vector index for DeepDive Ask Oracle RAG'
  );
end;
/

--------------------------------------------------------------------------------
-- D) ORACLELABS: combined RAG profile
--------------------------------------------------------------------------------

begin
  begin
    dbms_cloud_ai.drop_profile(profile_name => '&&COMBINED_RAG_PROFILE');
  exception
    when others then
      null;
  end;

  dbms_cloud_ai.create_profile(
    profile_name => '&&COMBINED_RAG_PROFILE',
    attributes => json_object(
      'provider'           value 'oci',
      'credential_name'    value '&&CREDENTIAL_NAME',
      'region'             value '&&OCI_GENAI_REGION',
      'model'              value '&&OCI_GENAI_MODEL',
      'oci_compartment_id' value '&&OCI_COMPARTMENT_ID',
      'vector_index_name'  value '&&COMBINED_VECTOR_INDEX_NAME',
      'conversation'       value 'true'
    ),
    status => 'enabled',
    description => 'DeepDive Ask Oracle combined RAG profile'
  );
end;
/

--------------------------------------------------------------------------------
-- E) ORACLELABS: optional Ask Oracle APEX defaults
--------------------------------------------------------------------------------

declare
  l_workspace_id number;
begin
  select workspace_id
    into l_workspace_id
    from apex_workspaces
   where workspace = upper('&&APEX_WORKSPACE');

  apex_util.set_security_group_id(l_workspace_id);

  apex_util.set_preference(
    p_preference => 'CLOUD_AI_PROFILE1',
    p_value      => '&&ASK_ORACLE_NL2SQL_PROFILE',
    p_user       => upper('&&APEX_USER')
  );

  apex_util.set_preference(
    p_preference => 'CLOUD_AI_RAG_PROFILE1',
    p_value      => '&&COMBINED_RAG_PROFILE',
    p_user       => upper('&&APEX_USER')
  );

  apex_util.set_preference(
    p_preference => 'CONVERSATION_STYLE',
    p_value      => 'rag_profiles',
    p_user       => upper('&&APEX_USER')
  );
exception
  when no_data_found then
    dbms_output.put_line('Workspace &&APEX_WORKSPACE not found. Skipping APEX defaults.');
  when others then
    dbms_output.put_line('Could not set APEX defaults: ' || sqlerrm);
end;
/

commit;


select profile_name, status, description
from user_cloud_ai_profiles
where profile_name in ('&&ASK_ORACLE_NL2SQL_PROFILE', '&&COMBINED_RAG_PROFILE')
order by profile_name;

select profile_name, attribute_name, to_char(attribute_value) attribute_value
from user_cloud_ai_profile_attributes
where profile_name in ('&&ASK_ORACLE_NL2SQL_PROFILE', '&&COMBINED_RAG_PROFILE')
  and attribute_name in ('OBJECT_LIST', 'VECTOR_INDEX_NAME')
order by profile_name, attribute_name;

select count(*) as total_matches
from bronze_wc_matches;

prompt Ask Oracle Select AI setup complete.

--------------------------------------------------------------------------------
-- Pruebas
--------------------------------------------------------------------------------


select dbms_cloud_ai.generate(
         prompt => 'Cuantos partidos jugo Argentina.',
         profile_name => 'DEEPDIVE_WC_NL2SQL',
         action => 'chat'
       ) as response
from dual;




select dbms_cloud_ai.generate(
         prompt => 'cual es el reglamento vigente?', 
         profile_name => 'DEEPDIVE_WC_RAG',
         action => 'narrate'
       ) as response
from dual;