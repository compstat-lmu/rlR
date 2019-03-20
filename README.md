[![Build Status](https://travis-ci.com/smilesun/rlR.svg?branch=master)](https://travis-ci.com/smilesun/rlR)
[![Coverage Status](https://coveralls.io/repos/github/smilesun/rlR/badge.svg?branch=master)](https://coveralls.io/github/smilesun/rlR?branch=master)
[![Build status](https://ci.appveyor.com/api/projects/status/d0oyb358bh3e8r7r?svg=true)](https://ci.appveyor.com/project/smilesun/rlr)
[Documentation](https://smilesun.github.io/rlR/)
# rlR: Deep Reinforcement learning in R

## Installation

### R package installation

```r
devtools::install_github("smilesun/rlR")
```
or 


```r
devtools::install_github("smilesun/rlR", dependencies = TRUE)
```

rlR itself use tensorflow as its backend for neural network as functional approximator, so python dependency is needed. 

### Configure to connect to python
To run the examples,  you need to have the python packages `numpy-1.14.5`, `tensorflow-1.8.0`, `keras-2.1.6`, `gym-0.10.5` installed in the **same** python path. 

This python path can be your system default python path or a virtual environment(either system python virtual environment or anaconda virtual environment).

Other package versions might also work but not tested.

To look at all python paths you have, in a R session, run

```r
reticulate::py_discover_config()
```

Check which is your system default python:

```r
Sys.which("python")
```

If you want to use a python path other than this system default, run the following(replace the '/usr/bin/python' with the python path you want) before doing anything else with reticulate.

```r
reticulate::use_python("/usr/bin/python", required=TRUE)
```
**"Note that you can only load one Python interpreter per R session so the use_python call only applies before you actually initialize the interpreter."** Which means if you changed your mind, you have to close the current R session and open a new R session.

Confirm from the following if the first path is the one you wanted

```r
reticulate::py_config()
```

### Python dependencies installation by rlR function
It is not recommended to mix things up with the system python, so by default, the rlR facility will install the dependencies to virtual environment named 'r-tensorflow' either to your system virtualenv or Anaconda virtualenv.

For Unix user
- Ensure that you have **either** of the following available
  - Python Virtual Environment: 
    
    ```bash
    pip install virtualenv
    ```
  - Anaconda
  - Native system  python that ships with your OS. (you have to install python libraries mannually in this case, see instructions below)
- Install dependencies through 
  - if you have python virtualenv available:
    
    ```r
    rlR::installDep2SysVirtualEnv(gpu = FALSE)
    ```
  - if you have anaconda available:
    
    ```r
    rlR::installDepConda(conda_path = "auto", gpu = FALSE)
    ```

For Windows user
- Ensure that you have Anaconda available **or** a native local system python installed(in this case you also have to install python libraries mannually, see instructions below)
- Install dependencies through `{r eval=FALSE} rlR::installDepConda(gpu = FALSE)` 

If you want to have gpu support, simply set the gpu argument to be true in the function call.

### Mannual python dependency installation
You can also install python dependencies without using rlR facility function, for example, you can open an anaconda virtual environment  "r-tensorflow" by `source activate r-tensorflow`

All python libraries that are required could be installed either in a virtual environment or in system native python using pip:


```bash
pip install --upgrade pip  # set your prefered path to the search path first
pip install -r requirement.txt
# or
pip install tensorflow
pip install keras
pip install gym
pip install cmake
pip install gym[atari]  # this need to be runned even you use require.txt for installation
```
where 'cmake' is required to build atari environments.

### Independencies for visualization of environments
The R package imager is required if you want to visualize different environments but the other functionality of rlR is not affected by this R package. For ubuntu, the R package imager depends on libraries which could be installed


```bash
sudo apt-get install -y libfftw3-dev libx11-dev libtiff-dev
sudo apt-get install -y libcairo2-dev
sudo apt-get install -y libxt-dev
```

## Usage

### Choose an environment to learn

```r
library(rlR)
env = makeGymEnv("CartPole-v1")
env
```

```
## 
## action cnt: 2 
## state original dim: 4 
## discrete action
```

If you have R package "imager" installed, you could get a snapshot of the environment by

```r
env$snapshot(preprocess = F)
```

### Choose a functional approximator to the value function
Neural Network functional approximator builder

```r
rlR:::makeValueNet
```

```
## function (state_dim, act_cnt) 
## {
##     model = keras_model_sequential()
##     model %>% layer_dense(units = 64, activation = "relu", input_shape = c(state_dim), 
##         kernel_regularizer = regularizer_l2(l = 0), bias_regularizer = regularizer_l2(l = 0)) %>% 
##         layer_dense(units = act_cnt, activation = "linear")
##     model$compile(loss = "mse", optimizer = optimizer_rmsprop(lr = 0.00025, 
##         decay = 0, clipnorm = 1))
##     return(model)
## }
## <environment: namespace:rlR>
```

### Initialize agent with the environment

```r
agent = initAgent("AgentDQN", env)
agent$customizeBrain(rlR:::makeValueNet, "value_fun")
agent$learn(200L)  
```

### Look at the performance

```r
agent$plotPerf(F)
```
