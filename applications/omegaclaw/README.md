# MetaMo OmegaClaw Application

This directory contains the MetaMo adapter and motivation logic for OmegaClaw.

## Installation

To set up and run this application, clone the necessary repositories and copy the run file:

```bash
git clone https://github.com/trueagi-io/PeTTa
cd PeTTa
mkdir -p repos
git clone https://github.com/asi-alliance/OmegaClaw-Core.git repos/OmegaClaw-Core
git clone https://github.com/patham9/petta_lib_chromadb.git repos/petta_lib_chromadb
git clone https://github.com/iCog-Labs-Dev/MetaMo.git MetaMo
cp MetaMo/applications/omegaclaw/run.metta ./run_omega.metta
```

## Usage

After copying the file, you can run the system from the root folder:

```bash
OMEGACLAW_AUTH_SECRET=<channel-secret> sh run.sh run_omega.metta IRC_channel="<irc-channel>" -s
```

*(Note: Replace `<channel-secret>` and `<irc-channel>` with your own values, similarly to the default OmegaClaw setup).*
