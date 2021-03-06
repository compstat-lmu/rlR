dqn.agent.nn.arch = list(nhidden = 64, act1 = "relu", act2 = "linear", loss = "mse", lr = 0.00025, kernel_regularizer = "regularizer_l2(l=0.0)", bias_regularizer = "regularizer_l2(l=0.0)")
makeValueNet.DQN =  function(state_dim, act_cnt) {
 model = keras_model_sequential();
 model %>% layer_dense(units = 64, activation = 'relu', input_shape = c(state_dim), kernel_regularizer = regularizer_l2(l = 0.0), bias_regularizer = regularizer_l2(l=0.0)) %>% layer_dense(units = act_cnt, activation = 'linear')
 model$compile(loss = 'mse', optimizer = optimizer_rmsprop(lr = 25e-5, decay = 0, clipnorm = 1.0))
 return(model)
}


makePolicyNet =  function(state_dim, act_cnt) {
  fun_loss = function(y_true, y_pred) {
    k_b = keras::backend()
    hh = k_b$print_tensor(y_true)
    temp = y_true * k_b$log(y_pred)
    sloss = -k_b$sum(temp)
    cross_entropy =  k_b$mean(sloss)
  }
 model = keras::keras_model_sequential();
 model %>% keras::layer_dense(units = 10, activation = 'tanh', input_shape = c(state_dim), kernel_initializer = keras::initializer_random_normal(mean = 0, std = 0.3), bias_initializer = keras::initializer_constant(0.1), name = "input") %>% layer_dense(units = act_cnt, activation = 'softmax', kernel_initializer = keras::initializer_random_normal(mean = 0, std = 0.3), bias_initializer = keras::initializer_constant(0.1), name = "output")
 model$compile(loss = fun_loss, optimizer = optimizer_rmsprop(lr = 1e-2, decay = 0, clipnorm = 5.0))
 return(model)
}



makeValueNet =  function(state_dim, act_cnt) {
 model = keras::keras_model_sequential();
 model %>% keras::layer_dense(units = 20, activation = 'relu', input_shape = c(state_dim), kernel_regularizer = regularizer_l2(l = 0.0), bias_regularizer = regularizer_l2(l=0.0)) %>% layer_dense(units = 1L, activation = 'linear')
 model$compile(loss = 'mse', optimizer = optimizer_rmsprop(lr = 25e-5, decay = 0, clipnorm = 1.0))
 return(model)
}

makePolicyNet2 =  function(state_dim, act_cnt) {
  fun_loss = function(y_true, y_pred) {
    k_b = keras::backend()
    hh = k_b$print_tensor(y_true)
    temp = y_true * k_b$log(y_pred)
    sloss = -k_b$sum(temp)
    cross_entropy =  k_b$mean(sloss)
  }
 model = keras::keras_model_sequential();
 model %>% keras::layer_dense(units = 20, activation = 'relu', input_shape = c(state_dim), kernel_initializer = keras::initializer_random_normal(mean = 0, std = 0.1), bias_initializer = keras::initializer_constant(0.1), name = "input") %>% layer_dense(units = act_cnt, activation = 'softmax', kernel_initializer = keras::initializer_random_normal(mean = 0, std = 0.1), bias_initializer = keras::initializer_constant(0.1), name = "output")
 model$compile(loss = fun_loss, optimizer = optimizer_adam(lr = 1e-3))
 return(model)
}

makeValueNet2 =  function(state_dim, act_cnt) {
 model = keras::keras_model_sequential();
 model %>% keras::layer_dense(units = 20, activation = 'relu', input_shape = c(state_dim), kernel_initializer = keras::initializer_random_normal(mean = 0, std = 0.1), bias_initializer = keras::initializer_constant(0.1), name = "input") %>% layer_dense(units = 1L, activation = 'linear')
 model$compile(loss = 'mse', optimizer = optimizer_adam(lr = 1e-2))
 return(model)
}





makeCompactableNet = function(state_dim, act_cnt) {
 input = keras::layer_input(shape = c(state_dim))
 hidden = input %>% keras::layer_dense(units = 64, activation = 'relu', kernel_regularizer = regularizer_l2(l = 0.0), bias_regularizer = regularizer_l2(l = 0.0))
 critic = hidden %>% keras::layer_dense(units = 1, activation = 'linear', name = "critic")
 actor = hidden %>% keras::layer_dense(units = act_cnt, activation = 'softmax', name = "actor")
 model = keras::keras_model(inputs = input, outputs = c(critic, actor))
 model %>% keras::compile(loss = list(critic = "mse", actor = "categorical_crossentropy"), optimizer = optimizer_rmsprop(lr = 25e-5, decay = 0, clipnorm = 1.0))
 return(model)
}


pg.agent.nn.arch = list(nhidden = 8, act1 = "relu", act2 = "softmax", loss = "categorical_crossentropy", lr = 25e-3, kernel_regularizer = "regularizer_l2(l=0.0)", bias_regularizer = "regularizer_l2(l=0)")
pg.bl.agent.nn.arch.actor = list(nhidden = 64, act1 = "tanh", act2 = "softmax", loss = "categorical_crossentropy", lr = 25e-3, kernel_regularizer = "regularizer_l2(l=0.0001)", bias_regularizer = "regularizer_l2(l=0.0001)", decay = 0.9, clipnorm = 5)
pg.bl.agent.nn.arch.critic = list(nhidden = 64, act1 = "tanh", act2 = "linear", loss = "mse", lr = 25e-3, kernel_regularizer = "regularizer_l2(l=0.0001)", bias_regularizer = "regularizer_l2(l=0)", decay = 0.9, clipnorm = 5)


makeKerasModel =  function(input_shape, output_shape, arch.list) {
  nhidden = arch.list$nhidden
  act1 = arch.list$act1
  act2 = arch.list$act2
  loss = arch.list$loss
  lr = arch.list$lr
  kernel_regularizer = arch.list$kernel_regularizer
  bias_regularizer = arch.list$bias_regularizer
  decay = arch.list$decay   # default is 0
  if (is.null(decay)) {
    decay = 0
  }
  clipnorm = arch.list$clipnorm  # default is NULL
  if (is.null(clipnorm)) {
    clipnorm = 1
  }
  mtext = "model = keras_model_sequential();
    model %%>%% layer_dense(units = %d, activation = '%s', input_shape = c(%d), kernel_regularizer = %s, bias_regularizer = %s) %%>%% layer_dense(units = %d, activation = '%s');
    model$compile(loss = '%s', optimizer = optimizer_rmsprop(lr = %f, decay = %f, clipnorm = %f));
    model"
  expr = sprintf(mtext, nhidden, act1, input_shape, kernel_regularizer, bias_regularizer, output_shape, act2, loss, lr, decay, clipnorm)
  eval(parse(text = expr))
}

makeNetFun = function(arch.list, flag_critic = F) {
  if (flag_critic)
  return( function(state_dim, act_cnt) {
    makeKerasModel(input_shape =state_dim, output_shape = 1, arch.list = arch.list)
  })

  function(state_dim, act_cnt) {
    makeKerasModel(input_shape = state_dim, output_shape = act_cnt, arch.list = arch.list)
  }
}

makeCnnActor = function(input_shape = c(32, 32, 3), act_cnt = 10L) {
  text = paste("model <- keras_model_sequential();",
  'model %>%',
  ' layer_conv_2d(filter = 32, kernel_size = c(8,8), strides = c(4, 4), padding = "same", input_shape = input_shape) %>%',
    'layer_activation("relu") %>%',
    'layer_conv_2d(filter = 64, kernel_size = c(4,4), strides = c(2, 2)) %>%',
    'layer_activation("relu") %>%',
#    'layer_max_pooling_2d(pool_size = c(2,2)) %>%',
#    'layer_dropout(0.25) %>%',
    'layer_conv_2d(filter = 32, kernel_size = c(3,3), strides = c(1,1), padding = "same") %>%',
    'layer_activation("relu") %>%',
#    'layer_max_pooling_2d(pool_size = c(2,2)) %>%',
#    'layer_dropout(0.25) %>%',
    'layer_flatten() %>%',
    'layer_dense(512) %>%',
    'layer_activation("relu") %>%',
#    'layer_dropout(0.5) %>%',
    'layer_dense(act_cnt) %>%',
    'layer_activation("softmax");',
    'opt <- optimizer_rmsprop(lr = 0.00025, decay = 1e-6);',
    'model %>% compile(loss = "categorical_crossentropy", optimizer = opt, metrics = "accuracy")')
  model = eval(parse(text = text))
  return(model)
}

makeCnnCritic = function(input_shape = c(32, 32, 3), act_cnt = 1L) {
  text = paste("model <- keras_model_sequential();",
  'model %>%',
  ' layer_conv_2d(filter = 32, kernel_size = c(8,8), strides = c(4, 4), padding = "same", input_shape = input_shape) %>%',
    'layer_activation("relu") %>%',
    'layer_conv_2d(filter = 64, kernel_size = c(4,4), strides = c(2, 2)) %>%',
    'layer_activation("relu") %>%',
    'layer_conv_2d(filter = 64, kernel_size = c(3,3), strides = c(1,1), padding = "same") %>%',
    'layer_activation("relu") %>%',
    'layer_flatten() %>%',
    'layer_dense(512) %>%',
    'layer_activation("relu") %>%',
    'layer_dense(act_cnt) %>%',
    'layer_activation("linear");',
    'opt <- optimizer_rmsprop(lr = 0.00025);',
    'model %>% compile(loss = "mse", optimizer = opt, metrics = "accuracy")')
  model = eval(parse(text = text))
  return(model)
}


checkCustomNetwork = function(fun, input_dim, output_dim) {
  checkmate::assertFunction(fun)
  res = try({
    do.call(fun, args = list(state_dim = input_dim, act_cnt = output_dim))
  })
  checkmate::assertFALSE(class(res)[1L] == "try-error")
  return(fun)
}
