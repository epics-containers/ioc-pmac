# Example hand coded IOC startup script for example-config
cd "/repos/epics/ioc"

epicsEnvSet "EPICS_CA_MAX_ARRAY_BYTES", '6000000'
epicsEnvSet "EPICS_CA_SERVER_PORT", '7064'

dbLoadDatabase "dbd/ioc.dbd"
ioc_registerRecordDeviceDriver(pdbbase)

dbLoadRecords("config/calc.db")
dbLoadRecords("/tmp/ioc.db")

iocInit()
