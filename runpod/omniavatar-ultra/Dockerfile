# OmniAvatar ULTRA - RunPod Serverless Template
# Full-body avatar video generation - 14B Model (BEST QUALITY)
# Requires: H100 80GB or A100 80GB
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

WORKDIR /workspace

# System dependencies
RUN apt-get update && apt-get install -y     git git-lfs ffmpeg libsm6 libxext6 libgl1-mesa-glx     && rm -rf /var/lib/apt/lists/* && git lfs install

# Clone OmniAvatar
RUN git clone https://github.com/Omni-Avatar/OmniAvatar.git

# Install dependencies
WORKDIR /workspace/OmniAvatar
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir flash_attn runpod huggingface_hub[cli]

# Create model directory
RUN mkdir -p pretrained_models

# Download 14B models (ULTRA quality - ~50GB total)
RUN huggingface-cli download Wan-AI/Wan2.1-T2V-14B --local-dir ./pretrained_models/Wan2.1-T2V-14B
RUN huggingface-cli download facebook/wav2vec2-base-960h --local-dir ./pretrained_models/wav2vec2-base-960h  
RUN huggingface-cli download OmniAvatar/OmniAvatar-14B --local-dir ./pretrained_models/OmniAvatar-14B

# Copy handler
COPY handler.py /workspace/handler.py

ENV PYTHONPATH="/workspace/OmniAvatar:$PYTHONPATH"
ENV HF_HOME="/workspace/huggingface"

CMD ["python", "/workspace/handler.py"]
