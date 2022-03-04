# Downstream Port Containment (DPC)

The relevant changes are presently in
- sys/dev/pci/pci-pci.c
- sys/dev/pci/pcireg.h
- sys/dev/pci/pcib_private.h

The sysctl `dev.pcib.N.software_trigger_dpc` can be used to synthesize a
DPC event, if the switch/bridge allows it.

## TODO
- Taskqueue thread needs to be created and interrupt work moved to it.
- Teardown code is needed
- It's unclear yet if DPC, HP, and AEN can share an MSI/MSIX vector.
