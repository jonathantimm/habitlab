(() => {

  if (window.show_user_info_interstitial) {
    return
  }
  window.show_user_info_interstitial = true

  require('enable-webcomponents-in-content-scripts')
  

  const $ = require('jquery')
  require('components/interstitial-screen-polymer.deps')
  const {
    get_minutes_spent_on_domain_today,
    get_visits_to_domain_today
  } = require('libs_common/time_spent_utils')

  const {
    log_impression,
    log_action,
  } = require('libs_common/log_utils')

  const {
    url_to_domain
  } = require('libs_common/domain_utils')


  get_minutes_spent_on_domain_today(url_to_domain(window.location.href), function(numMins){
    
    get_visits_to_domain_today(url_to_domain(window.location.href), function(numVisits) {
      
      console.log(numVisits)
      var titleString = 'You have visited ' + url_to_domain(window.location.href) +' ' + numVisits + ' times and spent '+ numMins + ' minutes there today.'
      var buttonText = 'Click to continue to Facebook'
      console.log(buttonText)
      var interst_screen = $('<interstitial-screen-polymer>')
      interst_screen.attr('btn-txt', buttonText)
      interst_screen.attr('title-text', titleString)
      log_impression(window.intervention.name, () =>{})
      $(document.body).append(interst_screen)
    })
  });
  

})()