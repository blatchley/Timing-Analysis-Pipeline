# Automated pipeline for Constant Time analysis of NIST candidates 
This is a collection of tools to help evaluate NIST lightweight crypto implementations for constant-time behaviour.

By [Adam B. Hansen](https://github.com/blatchley), [Eske Hoy Nielsen](https://github.com/4ever2) and [Morten Eskildsen](https://github.com/eskildsen), as a project for the Language Based Security course at Aarhus University.

1. [Installation](#Installation)
2. [Running Analysis Pipeline](#Running-Analysis-Pipeline)
3. [Using image without automated pipeline](#Using-image-without-automated-pipeline)
4. [Tools included](#Tools)
5. [Contributing](#Contributing)


## Installation
### Docker
Everything is packed in a Docker image. Thus, you will need to install Docker, if not already present on your system. For any Linux variant Docker can be installed with:
```
$ curl -fsSL https://get.docker.com -o get-docker.sh
$ sh get-docker.sh
```

For other operating systems and manuel installation take a look at [https://docs.docker.com/install/](https://docs.docker.com/install/).

## Running Analysis Pipeline
You can use an automated pipeline to validate your implementation against all tools included in the Docker image.
For using the pipeline we recommend using the prebuilt image available on Docer Hub.

### Running Analysis pipeline using ready-built image
To use the ready-built image for running the pipeline you can use the run script provided. The script takes two arguments, a source directory and a output directory. It is important that the paths you provide are absolute and they might need to be located under your $HOME.
```
$ ./run.sh "/source_dir" "/output_dir"
```

For more information about the format of the source folder or output folder read the section **Source and output folders** below.  For details on customization read the section **Customize** below.

If you for some reason cannot use the run script or want more control over docker settings you can run the pipeline directly by running
```
$ docker run --rm -it -v ~/source_dir:/root/source -v ~/out_dir:/root/out blatchley/ct-analysis:latest 
```

### Running Analysis pipeline using locally built image
Due to the time it takes to build and large memory consumption we recommend using the ready-built image. 
If you wish to run using manually built image you can use the `-b` flag on the run script. This will manually build the image and then run the pipeline. Due to Flowtracker this might take 50+ minutes.
```
$ ./run.sh -b "/source_dir" "/output_dir"
```

If you for some reason cannot use the run script or want more control over docker settings you can build and run the pipeline directly by running
```
$ docker build -t ct-analysis -f Dockerfile .
$ docker run --rm -it -v ~/source_dir:/root/source -v ~/out_dir:/root/out ct-analysis
```

### Source and output folders
For the automated pipeline to work a source and output directory must be mounted on the containter. Due to Docker these must be specified with absolute paths. 

The source directory must include the source code of the implementation you want to test. As specified by NIST there must be a `encrypt.c` file that includes `crypto_aead.h`, and there must also be a `api.h` file following the same format. Optionally you can also provide a `settings.h` file to customize how the pipeline runs, if not provided default settings are used. For more details on settings see the **Customize** section below.

The output directory is where the pipeline writes the results. It will write a summary of everything to `summary.txt` this file includes the main takeaway from each tool. For more detailed output from each tool see the files `ctgrind.out`, `dudect.out` and `flowtracker.out`. Additionally flowtracker generates graphs of the source and vulnerable parts of the source. These can be found in the `flowtracker` directory.

### Customize
The automated pipeline can be customized by providing a `settings.h` file in the mounted source directory. If it is not provided a default settings file will be used. The default settings file looks as follows
```c
#define ANALYSE_ENCRYPT 1         // If set to 1 analyse crypto_aead_encrypt funtion otherwise analyse crypto_aead_decrypt
#define DUDECT_MEASUREMENTS 1e6   // Number of encrypt or decrypt exeutions each iteration of dudect
#define DUDECT_TIMEOUT 600        // Upper limit on how long the dudect tool will run
#define CTGRIND_SAMPLE_SIZE 1e2   // Number of random executions of encrypt or decrypt in ctgrind tool
#define CRYPTO_MSGBYTES 32        // Size of msg encrypted
#define CRYPTO_ADBYTES 4          // Size of ad
```

## Using image without automated pipeline
You can use a container with all the tools already compiled by issuing the command below. This will give you a shell within the container with the tools ready to use. 
```
$ docker run --entrypoint=/bin/bash blatchley/ct-analysis:latest  
```
Currently there are not any build and execute scripts for the different tools, so if you want to play around with the tools you have to manually build your source code with them.

## Tools
Currently the Docker image and pipeline includes three constant time analysis tools.

DudeCT: https://github.com/oreparaz/dudect

CTGrind: https://github.com/agl/ctgrind

FlowTracker
