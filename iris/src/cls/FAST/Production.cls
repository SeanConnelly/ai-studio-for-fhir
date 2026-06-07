/// The FAST Interoperability Production: real Business Service + Process +
/// Operations that execute compiled agent recipes. Openable in the Management
/// Portal (Interoperability → Configure → Production) with real Visual Trace.
Class FAST.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="FAST.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>FHIR Agent Studio — AI-agent interoperability production</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="AgentTriggerService" Category="" ClassName="FAST.BS.AgentTriggerService" PoolSize="1" Enabled="true" LogTraceEvents="true"/>
  <Item Name="AgentOrchestrator" Category="" ClassName="FAST.BP.AgentOrchestrator" PoolSize="1" Enabled="true" LogTraceEvents="true"/>
  <Item Name="AIHub" Category="" ClassName="FAST.BP.AIHub" PoolSize="1" Enabled="true" LogTraceEvents="true"/>
  <Item Name="FHIRRead" Category="Operations" ClassName="FAST.BO.FHIRRead" PoolSize="1" Enabled="true" LogTraceEvents="true"/>
  <Item Name="SQLQuery" Category="Operations" ClassName="FAST.BO.SQLQuery" PoolSize="1" Enabled="true" LogTraceEvents="true"/>
  <Item Name="VectorSearch" Category="Operations" ClassName="FAST.BO.VectorSearch" PoolSize="1" Enabled="true" LogTraceEvents="true"/>
  <Item Name="LLMService" Category="Operations" ClassName="FAST.BO.LLMService" PoolSize="1" Enabled="true" LogTraceEvents="true">
    <Setting Target="Adapter" Name="HTTPServer">api.x.ai</Setting>
    <Setting Target="Adapter" Name="HTTPPort">443</Setting>
    <Setting Target="Adapter" Name="URL">/v1/chat/completions</Setting>
    <Setting Target="Adapter" Name="SSLConfig">fhiras_ssl</Setting>
    <Setting Target="Adapter" Name="ResponseTimeout">90</Setting>
  </Item>
  <Item Name="FHIRWriteback" Category="Operations" ClassName="FAST.BO.FHIRWriteback" PoolSize="1" Enabled="true" LogTraceEvents="true"/>
</Production>
}

}
