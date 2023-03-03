TOP = ../..
include $(TOP)/configure/CONFIG

PROD_IOC = ioc
DBD += ioc.dbd
ioc_DBD += base.dbd
ioc_DBD += devIocStats.dbd
ioc_DBD += asyn.dbd
ioc_DBD += pmacAsynIPPort.dbd
ioc_DBD += motorSupport.dbd
ioc_DBD += devSoftMotor.dbd
ioc_DBD += pmacAsynMotorPort.dbd
ioc_DBD += busySupport.dbd
ioc_DBD += calcSupport.dbd
ioc_SRCS += ioc_registerRecordDeviceDriver.cpp

ioc_LIBS += calc
ioc_LIBS += busy
ioc_LIBS += pmacAsynMotorPort
ioc_LIBS += softMotor
ioc_LIBS += motor
ioc_LIBS += pmacAsynIPPort
ioc_LIBS += asyn
ioc_LIBS += devIocStats
ioc_LIBS += $(EPICS_BASE_IOC_LIBS)
ioc_SRCS += iocMain.cpp

include $(TOP)/configure/RULES
