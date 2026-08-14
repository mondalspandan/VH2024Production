import os
import os.path

import FWCore.ParameterSet.Config as cms


mass = os.environ["VH_MASS"]
hadron_flavour = os.environ["VH_HADFLAV"]
gridpack_dir = os.environ.get("VH_GRIDPACK_DIR", ".")
gridpack = os.path.join(
    gridpack_dir,
    f"HZJ_el8_amd64_gcc12_CMSSW_14_0_21_HZJ_{mass}.tgz",
)

externalLHEProducer = cms.EDProducer(
    "ExternalLHEProducer",
    args=cms.vstring(gridpack),
    nEvents=cms.untracked.uint32(5000),
    generateConcurrently=cms.untracked.bool(True),
    numberOfParameters=cms.uint32(1),
    outputFile=cms.string("cmsgrid_final.lhe"),
    scriptName=cms.FileInPath(
        "GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh"
    ),
)

from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *
from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.Pythia8PowhegEmissionVetoSettings_cfi import *


generator = cms.EDFilter(
    "Pythia8ConcurrentHadronizerFilter",
    maxEventsToPrint=cms.untracked.int32(1),
    pythiaPylistVerbosity=cms.untracked.int32(1),
    filterEfficiency=cms.untracked.double(1.0),
    pythiaHepMCVerbosity=cms.untracked.bool(False),
    comEnergy=cms.double(13600.0),
    PythiaParameters=cms.PSet(
        pythia8CommonSettingsBlock,
        pythia8CP5SettingsBlock,
        pythia8PSweightsSettingsBlock,
        pythia8PowhegEmissionVetoSettingsBlock,
        processParameters=cms.vstring(
            "POWHEG:nFinal = 3",
            f"25:m0 = {mass}.0",
            "25:onMode = off",
            f"25:onIfMatch = {hadron_flavour} -{hadron_flavour}",
        ),
        parameterSets=cms.vstring(
            "pythia8CommonSettings",
            "pythia8CP5Settings",
            "pythia8PSweightsSettings",
            "pythia8PowhegEmissionVetoSettings",
            "processParameters",
        ),
    ),
)

ProductionFilterSequence = cms.Sequence(generator)
