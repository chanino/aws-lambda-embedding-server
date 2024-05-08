# Use the ARM64 version of Amazon Linux 2
FROM arm64v8/amazonlinux:2

# Install necessary packages, including development tools and utilities
RUN yum update -y && \
    yum install -y gcc-c++ make git openssl-devel zlib-devel libcurl-devel tar gzip

# Install CMake from official source
# Assume this has been run:
# curl -sL https://github.com/Kitware/CMake/releases/download/v3.20.2/cmake-3.20.2.tar.gz -o cmake.tar.gz
ARG CMAKE_VERSION=3.20.2
COPY cmake.tar.gz /app/
RUN cd /app && \
    tar -zxvf cmake.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./bootstrap && \
    make && \
    make install && \
    cd / && \
    rm -rf /app/cmake-${CMAKE_VERSION} /app/cmake.tar.gz

# Install cJSON
# Assume this has been run:
# git clone https://github.com/DaveGamble/cJSON
COPY ./cJSON /app/cJSON
RUN cd /app/cJSON && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && make install && \
    rm -rf /app/cJSON

# Clone and build aws-lambda-cpp runtime
# Assume this has been run:
# git clone https://github.com/awslabs/aws-lambda-cpp.git
COPY ./aws-lambda-cpp /app/aws-lambda-cpp
RUN cd /app/aws-lambda-cpp && \
    mkdir build && \
    cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make && make install && \
    rm -rf /app/aws-lambda-cpp

# Assume this has been run:
# curl -sL https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf
COPY ./nomic-embed-text-v1.5.Q8_0.gguf /app/nomic-embed-text-v1.5.Q8_0.gguf
# git clone https://github.com/ggerganov/llama.cpp.git
# plus edits
COPY ./llama.cpp/ /app/llama.cpp

# Run the rest of this as non-root
RUN groupadd -r myuser && useradd -r -g myuser myuser

# Change ownership of the /app directory (or specific subdirectories)
RUN chown -R myuser:myuser /app/llama.cpp  # Ensure ownership

USER myuser

# Set the working directory to where your llama code is
WORKDIR /app/llama.cpp

# Set the LD_LIBRARY_PATH to find cJSON
ENV LD_LIBRARY_PATH=/usr/local/lib64:${LD_LIBRARY_PATH}

# Build your C++ application using make
RUN make embedding_main

# Command to run your compiled program (if testing locally, otherwise use for packaging)
CMD ["./embedding_main"]
