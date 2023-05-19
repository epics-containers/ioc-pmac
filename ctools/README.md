The Ctools directory contains scripts that support epics-containers IOCs,
the contents of this folder is usually inherited from the epics-base
container image.

Here we allow overriding or adding to the ctools files supplied by epics-base.

This allows us to update these files for IOC builds without
rebuilding the entire stack of containers.

Where practical, files in this folder should get pushed back into
epics-base/ctools each time a new release of epics-base is
happening.

Placing files in here runs the risk that this module will not pick up
updates from epics-base and should be used sparingly.
