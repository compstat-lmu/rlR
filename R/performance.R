Performance = R6::R6Class("Performance",
  public = list(
    list.reward.epi = NULL,  # take reward vector of each episode
    list_discount_reward_epi = NULL,  # discounted reward per episode
    list.rewardPerEpisode = NULL,  # sum up reward of each episode
    rewardPerStep = NULL,
    list_steps_epi = NULL,
    list.infos = NULL,
    epiLookBack = NULL,
    epi_idx = NULL,
    glogger = NULL,
    agent = NULL,
    r.vec.epi = NULL,
    gamma = NULL,
    total_steps = NULL,
    list_models = NULL,
    store_model_flag = NULL,
    initialize = function(agent) {
      self$epiLookBack = 100L
      self$agent = agent
      self$gamma = self$agent$conf$get("agent.gamma")
      self$glogger = self$agent$glogger
      self$list.reward.epi = list()
      self$list.infos = list()
      self$list_discount_reward_epi = list()
      self$epi_idx = 0L
      self$list.rewardPerEpisode = list()
      self$list_steps_epi = list()
      self$r.vec.epi = vector(mode = "numeric", length = self$agent$env$maxStepPerEpisode)
      self$store_model_flag = self$agent$conf$get("agent.store.model")
      if (is.null(self$store_model_flag)) self$store_model_flag = FALSE
      if (self$store_model_flag) self$list_models = list()
    },

    computeDiscount = function(rewardvec) {
      discounted_r = vector(mode = "double", length = length(rewardvec))
      running_add = 0
      i = length(rewardvec)
      while (i > 0) {
        running_add = running_add * self$gamma + rewardvec[i]
        discounted_r[i] = running_add
        i = i - 1L
      }
      discounted_r
    },

    persist = function(path) {
      perf = self$clone()
      save(perf, file = path)
    },

   getAccPerf = function(interval = 100L) {
      self$list.rewardPerEpisode = lapply(self$list.reward.epi, function(x) sum(x))
      epi_idx = length(self$list.rewardPerEpisode)
      winstart = max(1L, epi_idx - interval)
      vec = unlist(self$list.rewardPerEpisode)
      mean(vec[winstart:epi_idx], na.rm = TRUE)
    },

   psummary = function() {
      s1 = sprintf("steps per episode:%s \n", toString(self$list_steps_epi))
      self$list.rewardPerEpisode = lapply(self$list.reward.epi, function(x) sum(x))
      s2 = sprintf("total reward per episode: %s \n", toString(self$list.rewardPerEpisode))
      self$rewardPerStep = unlist(self$list.rewardPerEpisode) / unlist(self$list_steps_epi)
      s3 = sprintf("reward per step per episode:%s \n", toString(self$rewardPerStep))
      paste(s1, s2, s3)
    },

    plot = function(smooth = TRUE) {
      self$list.rewardPerEpisode = lapply(self$list.reward.epi, function(x) sum(x))
      env_name = self$agent$env$name
      class_name = class(self$agent)[1]
      title = substitute(paste("Rewards per Episode of ", class_name, " for ", env_name, sep = ""), list(class_name = class_name, env_name = env_name))
      rewards = unlist(self$list.rewardPerEpisode)
      df = data.frame(episode = seq_along(rewards),
        rewards = rewards)
      if (smooth) {
        ggplot2::ggplot(df, aes(episode, rewards), col = "brown1") +
          geom_point(alpha = 0.2) +
          theme_bw() +
          labs(
            title = title,
            x = "Episode",
            y = "Rewards per episode"
            ) +
          coord_cartesian(ylim = range(rewards)) +
          geom_smooth(se = FALSE, size = 1) +
          geom_hline(yintercept = median(rewards), size = 1, col = "black", lty = 2)
      } else {
          ggplot2::ggplot(df, aes(episode, rewards)) +
          geom_line() +
          theme_bw() +
          labs(
            title = title,
            x = "Episode",
            y = "Rewards per episode"
            ) + coord_cartesian(ylim = range(rewards))
      }
    },

    toScalar = function() {
      self$getAccPerf(100L)
    },

    extractInfo = function() {
      self$list.infos = lapply(self$agent$mem$samples, function(x) x$info)
    },

    afterAll = function() {
      self$psummary()   # print out performance
      ns = self$agent$conf$conf.log.perf$resultTbPath
      if (self$glogger$flag) self$persist(file.path(ns))
      self$extractInfo()
    },

    afterEpisode = function() {
      self$agent$interact$idx_episode = self$agent$interact$idx_episode + 1L
      self$agent$interact$glogger$log.nn$info("Episode: %i, steps:%i\n", self$agent$interact$idx_episode, self$agent$interact$step_in_episode)
      rewards = sum(self$r.vec.epi[1L:self$agent$interact$step_in_episode])
      self$agent$interact$toConsole("Episode: %i finished with steps:%i, rewards:%f global step %i \n", self$agent$interact$idx_episode, self$agent$interact$step_in_episode, rewards, self$agent$interact$global_step_len)
      self$epi_idx = self$epi_idx + 1L
      self$list.reward.epi[[self$epi_idx]] = vector(mode = "list")
      self$list.reward.epi[[self$epi_idx]] = self$r.vec.epi[1L:self$agent$interact$step_in_episode]   # the reward vector
      self$list_discount_reward_epi[[self$epi_idx]] = self$computeDiscount(self$r.vec.epi[1L:self$agent$interact$step_in_episode])
      self$list_steps_epi[[self$epi_idx]] = self$total_steps = self$agent$interact$step_in_episode  # the number of steps
      rew = self$getAccPerf(self$epiLookBack)
      self$agent$interact$toConsole("Last %d episodes average reward %f \n", self$epiLookBack, rew)
      if (self$store_model_flag) {
        len = length(self$list_models)
        self$list_models[[len + 1L]] = self$agent$model$clone(deep = TRUE)
      }
    },
    print = function() {
    }
    )
)


PerfRescue = R6::R6Class("PerfRescue",
  inherit = Performance,
  public = list(
    epi_wait_ini = NULL,   # number of episode to wait until to reinitialize
    epi_wait_expl = NULL,  # number of episode to wait until to increase epsilon for exploration
    recent_win = NULL,
    recent_door = NULL,
    bad_ratio = NULL,
    good_cnt = NULL,
    wait_epi = NULL,
    wait_cnt = NULL,
    wait_middle = NULL,
    reset_cnt = NULL,
    initialize = function() {
      self$reset_cnt = 0L
      self$wait_epi = rlR.conf4log[["policy.epi_wait_ini"]]
      self$wait_cnt = 0L
      self$good_cnt = 0L
      self$recent_win = 20L
      self$recent_door = 40L
      self$bad_ratio = 0.99
      self$wait_middle = rlR.conf4log[["policy.epi_wait_middle"]]
      self$epi_wait_ini = rlR.conf4log[["policy.epi_wait_ini"]]
      self$epi_wait_expl = rlR.conf4log[["policy.epi_wait_expl"]]

    },

    success = function() {
      ok_reward = self$agent$env$ok_reward
      ok_step = self$agent$env$ok_step
      if (is.null(ok_reward) || is.null(ok_step)) {
        return(FALSE)
      }
      if (self$getAccPerf(ok_step) > ok_reward) {
        return(TRUE)
      }
      return(FALSE)
    },

    isBad = function() {
      pwin = self$getAccPerf(self$recent_win)
      pdoor = self$getAccPerf(self$recent_door)
      self$agent$interact$toConsole("Last %d episodes average reward %f \n", self$recent_win, pwin)
      self$agent$interact$toConsole("Last %d episodes average reward %f \n", self$recent_door, pdoor)
      all_rewards = unlist(self$list.rewardPerEpisode)
      flag1 = pwin < self$bad_ratio * pdoor
      flag2 = pwin < (1/self$bad_ratio) * self$getAccPerf(100L)
      flag2old = flag2
      flag3 = pwin < median(all_rewards)
      flag4 = pwin < mean(all_rewards)
      flag22 = (flag2 || flag2old)
      if (!flag22)  self$good_cnt = self$good_cnt + 1L
      else self$good_cnt = 0L
      res = c(flag1, flag2, flag3, flag4, flag22)
      names(res) = c("bad_small", "bad_middle", "bad_big1", "bad_big2", "bad_middle2")
      self$agent$interact$toConsole("%s", toString(res))
      return(res)
    },

    rescue = function() {
      flag = self$isBad()
      self$wait_epi = min(self$epi_wait_expl, self$wait_epi + 1)
      if (flag[1]) {
        self$agent$interact$toConsole("\n bad perform for last window, %d times \n", self$wait_cnt + 1L)
        self$wait_cnt = self$wait_cnt + 1L
        ratio = exp(-self$agent$policy$logdecay * self$total_steps)
        #self$agent$policy$epsilon = min(1, self$agent$policy$epsilon * ratio)  #FIXME: shall we increase explore here ? Again and again exporation will never converge
        flag_new_start = self$wait_cnt > self$wait_middle         
        flag_start = all(flag) && flag_new_start
        if (self$wait_cnt > self$wait_epi || flag_start) {
          if (flag[2] || flag[3]) {
            self$agent$interact$toConsole("\n\n### going to reset brain ###\n\n\n")
            self$agent$setBrain()
            self$wait_epi = self$agent$conf$get("policy.epi_wait_expl")
            self$reset_cnt = self$reset_cnt + 1L
            self$agent$policy$epsilon = self$agent$policy$maxEpsilon
            self$wait_cnt = 0
          } else {
            self$wait_cnt = max(0, self$wait_cnt - 1)
            self$agent$policy$epsilon = self$agent$policy$maxEpsilon
          }
        }
      } else {
        if (self$good_cnt > 5L) {
          self$agent$interact$toConsole("\n# success more than 5 \n")
          self$wait_cnt = max(0, self$wait_cnt - self$wait_epi)
      }}
      #else if (flag["bad_middle2"])
      # self$wait_cnt = max(0, self$wait_cnt - 1)
      # }
      self$agent$interact$toConsole("\n wait cnt: %d times \n", self$wait_cnt)
    } # fun
    )
)
