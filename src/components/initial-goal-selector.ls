{cfy} = require 'cfy'
prelude = require 'prelude-ls'
$ = require 'jquery'

swal = require 'sweetalert2'

{load_css_file} = require 'libs_common/content_script_utils'

{
  get_enabled_goals
  get_goals
  set_goal_target
  get_goal_target
  remove_custom_goal_and_generated_interventions
  add_enable_custom_goal_reduce_time_on_domain
  set_goal_enabled_manual
  set_goal_disabled_manual
} = require 'libs_backend/goal_utils'

{
  get_interventions
  get_enabled_interventions
  set_intervention_disabled
} = require 'libs_backend/intervention_utils'


{
  enable_interventions_because_goal_was_enabled
} = require 'libs_backend/intervention_manager'

{
  add_log_interventions
} = require 'libs_backend/log_utils'


{
  url_to_domain
} = require 'libs_common/domain_utils'

{
  get_canonical_domain
} = require 'libs_backend/canonical_url_utils'

{
  msg
} = require 'libs_common/localization_utils'

{polymer_ext} = require 'libs_frontend/polymer_utils'

polymer_ext {
  is: 'initial-goal-selector'
  properties: {
    sites_and_goals: {
      type: Array
      value: []
    }
    daily_goal_values: {
      type: Array
      value: ["5 minutes", "10 minutes", "15 minutes", "20 minutes", "25 minutes", "30 minutes", "35 minutes", "40 minutes", "45 minutes", "50 minutes", "55 minutes", "60 minutes"]
    }
    index_of_daily_goal_mins: {
      type: Object
      value: {}
    },
    title_text: {
      type: String
      value: msg("Based on your browsing history, HabitLab has come up with a list of suggested sites for you.")
    }
    title_text_bolded_portion: {
      type: String
      value: msg("Select the sites you'd like to spend less time on.")
    }
    isdemo: {
      type: Boolean
      observer: 'isdemo_changed'
    }
    title: {
      type: String
      value: msg("Let's set some goals.")
    }

  }
  isdemo_changed: (isdemo) ->
    if isdemo
      this.set_sites_and_goals()
      document.body.style.backgroundColor = 'white'
  delete_goal_clicked: (evt) ->>
    goal_name = evt.target.goal_name
    await remove_custom_goal_and_generated_interventions goal_name
    await this.set_sites_and_goals()
    this.fire 'need_rerender', {}
  disable_interventions_which_do_not_satisfy_any_goals: (goal_name) ->>
    enabled_goals = await get_enabled_goals()
    enabled_interventions = await get_enabled_interventions()
    all_interventions = await get_interventions()
    interventions_to_disable = []
    for intervention_name,intervention_enabled of enabled_interventions
      if not intervention_enabled
        continue
      intervention_info = all_interventions[intervention_name]
      intervention_satisfies_an_enabled_goal = false
      for goal_name in intervention_info.goals
        if enabled_goals[goal_name]
          intervention_satisfies_an_enabled_goal = true
      if not intervention_satisfies_an_enabled_goal
        interventions_to_disable.push intervention_name
    prev_enabled_interventions = {} <<< enabled_interventions
    for intervention_name in interventions_to_disable
      await set_intervention_disabled intervention_name
    if interventions_to_disable.length > 0
      add_log_interventions {
        type: 'interventions_disabled_due_to_user_disabling_goal'
        manual: false
        goal_name: goal_name
        interventions_list: interventions_to_disable
        prev_enabled_interventions: prev_enabled_interventions
      }
  time_updated: (evt, obj) ->>
    mins = Number (obj.item.innerText.trim ' ' .split ' ' .0)
    set_goal_target obj.item.class, mins
  get_daily_targets: ->>
    goals = await get_goals!
    for goal in Object.keys goals
      if goal == "debug/all_interventions" 
        continue
      mins = await get_goal_target goal
      mins = mins/5 - 1
      this.index_of_daily_goal_mins[goal] = mins
  show_internal_names_of_goals: ->
    return localStorage.getItem('intervention_view_show_internal_names') == 'true'
  daily_goal_help_clicked: ->
    swal {
      title: 'How are Daily Goals used?'
      text: 'Your daily goal is used only to display your progress. If you exceed your daily goal, HabitLab will continue to show interventions as usual (it will not block the site).'
    }
  settings_goal_clicked: (evt) ->
    evt.preventDefault()
    evt.stopPropagation()
    newtab = evt.target.sitename
    this.fire 'need_tab_change', {newtab: newtab}
  is_goal_shown: (goal) ->
    if goal.hidden and localStorage.getItem('show_hidden_goals_and_interventions') != 'true'
      return false
    if goal.beta and localStorage.getItem('show_beta_goals_and_interventions') != 'true'
      return false
    return true
  set_sites_and_goals: ->>
    self = this
    goal_name_to_info = await get_goals()
    sitename_to_goals = {}
    for goal_name,goal_info of goal_name_to_info
      if goal_name == 'debug/all_interventions' and localStorage.getItem('intervention_view_show_debug_all_interventions_goal') != 'true'
        continue
      sitename = goal_info.sitename_printable
      if not sitename_to_goals[sitename]?
        sitename_to_goals[sitename] = []
      sitename_to_goals[sitename].push goal_info
    list_of_sites_and_goals = []
    list_of_sites = prelude.sort Object.keys(sitename_to_goals)
    enabled_goals = await get_enabled_goals()
    await this.get_daily_targets!
    
    for sitename in list_of_sites
      current_item = {sitename: sitename}
      current_item.goals = prelude.sort-by (.name), sitename_to_goals[sitename]
      
      for goal in current_item.goals
        goal.enabled = (enabled_goals[goal.name] == true)
        goal.number = this.index_of_daily_goal_mins[goal.name]
        
      

      list_of_sites_and_goals.push current_item
    self.sites_and_goals = list_of_sites_and_goals
  goal_changed: (evt) ->>
    
    checked = evt.target.checked
    
    goal_name = evt.target.goal.name


    self = this
    if checked
      await set_goal_enabled_manual goal_name
      
      check_if_first_goal = ->>       
        if !localStorage.first_goal?
          localStorage.first_goal = 'has enabled a goal before'
          #add_toolbar_notification!

          # await load_css_file('bower_components/sweetalert2/dist/sweetalert2.css')
          # try
          #   await swal {
          #     title: 'You set a goal!'
          #     text: 'HabitLab will use its algorithms to try different interventions on your webpages, and intelligently figure out what works best for you. You can manually tinker with settings if you\'d like.'
          #     type: 'success'
          #     confirmButtonText: 'See it in action'
          #   }
            
          #   set_override_enabled_interventions_once('facebook/show_user_info_interstitial')
          #   all_goals = await get_goals()
          #   goal_info = all_goals[goal_name]
          #   chrome.tabs.create {url: goal_info.homepage }
          # catch
          #   console.log 'failure'
      check_if_first_goal!
    else
      await set_goal_disabled_manual goal_name
    await this.disable_interventions_which_do_not_satisfy_any_goals(goal_name)
    if checked
      await enable_interventions_because_goal_was_enabled(goal_name)
    
    await self.set_sites_and_goals()
    self.fire 'goal_changed', {goal_name: goal_name}
<<<<<<< HEAD
  should_have_newline: (index, num_per_line) ->
    return (index % num_per_line) == 0 
  sort_custom_sites_after_and_limit_to_eight: (sites_and_goals) ->
    return this.sort_custom_sites_after(sites_and_goals)[0 til 8]
=======
>>>>>>> iqiyi
  sort_custom_sites_after: (sites_and_goals) ->
    [custom_sites_and_goals,normal_sites_and_goals] = prelude.partition (-> it.goals.filter((.custom)).length > 0), sites_and_goals
    return normal_sites_and_goals.concat custom_sites_and_goals
  image_clicked: (evt) ->
    console.log 'clicked image:'
    console.log evt.target.goalname
  add_goal_clicked: (evt) ->
    this.add_custom_website_from_input()
    return
  add_website_input_keydown: (evt) ->
    if evt.keyCode == 13
      # enter pressed
      this.add_custom_website_from_input()
      return
  add_custom_website_from_input: ->>
    domain = url_to_domain(this.$$('#add_website_input').value.trim())
    if domain.length == 0
      return
    this.$$('#add_website_input').value = ''
    canonical_domain = await get_canonical_domain(domain)
    if not canonical_domain?
      swal {
        title: 'Invalid Domain'
        html: $('<div>').append([
          $('<div>').text('You entered an invalid domain: ' + domain)
          $('<div>').text('Please enter a valid domain such as www.amazon.com')
        ])
        type: 'error'
      }
      return
    if domain != canonical_domain
      await add_enable_custom_goal_reduce_time_on_domain(domain)
    await add_enable_custom_goal_reduce_time_on_domain(canonical_domain)
    await this.set_sites_and_goals()
    this.fire 'need_rerender', {}
    return
  ready: ->>
<<<<<<< HEAD
    self = this
    self.on_resize '#outer_wrapper', ->
      console.log 'resized!!'
      leftmost = null
      rightmost = null
      for icon in $('.siteicon')
        width = $(icon).width()
        left = $(icon).offset().left
        right = left + width
        if (leftmost == null) or left < leftmost
          leftmost = left
        if (rightmost == null) or right > rightmost
          rightmost = right
      total_width = $(self).width()
      margin_needed = ((total_width - (rightmost - leftmost)) / 2)-15
      #$('.flexcontainer').css('margin-left', margin_needed)
      current_offset = $('.flexcontainer').offset()
      $('.flexcontainer').offset({left: margin_needed, top: current_offset.top})
=======
>>>>>>> master
    load_css_file('bower_components/sweetalert2/dist/sweetalert2.css')
}, [
  {
    source: require 'libs_common/localization_utils'
    methods: [
      'msg'
    ]
  }
  {
    source: require 'libs_frontend/polymer_methods'
    methods: [
      'on_resize'
    ]
  }
]