# ============================================================================
# OMNIAVATAR RUNPOD SERVERLESS - BroyhillGOP E48 ULTRA VIDEO
# Full-body avatar video generation (95/100 quality)
# Replaces: HeyGen ($180/mo), D-ID ($299/mo), Synthesia ($67/mo)
# ============================================================================
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    git-lfs \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

# Initialize git lfs
RUN git lfs install

# Clone OmniAvatar
RUN git clone https://github.com/Omni-Avatar/OmniAvatar.git

# Install PyTorch (already in base, but ensure correct version)
RUN pip install --no-cache-dir torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu124

# Install OmniAvatar dependencies
WORKDIR /workspace/OmniAvatar
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir flash_attn runpod requests

# Create model directory
RUN mkdir -p pretrained_models

# Download models (1.3B version - fits RTX 4090 24GB)
RUN pip install --no-cache-dir "huggingface_hub[cli]"

# Download Wan base model (1.3B)
RUN huggingface-cli download Wan-AI/Wan2.1-T2V-1.3B --local-dir ./pretrained_models/Wan2.1-T2V-1.3B

# Download wav2vec audio encoder
RUN huggingface-cli download facebook/wav2vec2-base-960h --local-dir ./pretrained_models/wav2vec2-base-960h

# Download OmniAvatar LoRA weights (1.3B)
RUN huggingface-cli download OmniAvatar/OmniAvatar-1.3B --local-dir ./pretrained_models/OmniAvatar-1.3B

# Copy handler
WORKDIR /workspace
COPY rp_handler.py /workspace/rp_handler.py

# Create outputs directory
RUN mkdir -p /workspace/OmniAvatar/outputs

# Environment
ENV PYTHONPATH="/workspace/OmniAvatar:$PYTHONPATH"
ENV HF_HOME="/workspace/huggingface"
ENV CUDA_VISIBLE_DEVICES=0

# Run handler
CMD ["python", "-u", "/workspace/rp_handler.py"]
