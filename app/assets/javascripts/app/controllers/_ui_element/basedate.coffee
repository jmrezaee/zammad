# coffeelint: disable=camel_case_classes
# Base class for providing date picker. Must be extended
class App.UiElement.basedate
  @templateName: ->
    throw 'Must override in a subclass'

  @JALALI_MONTH_NAMES: ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند']

  @isJalali: ->
    App.i18n.get() is 'fa-ir'

  # Converts a Gregorian date (1-based month) to Jalali {jy, jm, jd}.
  # Algorithm adapted from jalaali-js (MIT License).
  @dateToJalali: (gy, gm, gd) ->
    gy -= 1600; gm -= 1; gd -= 1
    g_d_no = 365 * gy + Math.floor((gy + 3) / 4) - Math.floor((gy + 99) / 100) + Math.floor((gy + 399) / 400)
    gMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    for days, i in gMonthDays
      break if i >= gm
      g_d_no += days
    if gm > 1 and ((gy % 4 is 0 and gy % 100 isnt 0) or (gy % 400 is 0))
      g_d_no++
    g_d_no += gd
    j_d_no = g_d_no - 79
    j_np = Math.floor(j_d_no / 12053); j_d_no %= 12053
    jy = 979 + 33 * j_np + 4 * Math.floor(j_d_no / 1461)
    j_d_no %= 1461
    if j_d_no >= 366
      jy += Math.floor((j_d_no - 1) / 365)
      j_d_no = (j_d_no - 1) % 365
    jMonthDays = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29]
    jm = 0
    while jm < 11 and j_d_no >= jMonthDays[jm]
      j_d_no -= jMonthDays[jm]
      jm++
    { jy, jm: jm + 1, jd: j_d_no + 1 }

  @toPersianDigits: (n) ->
    "#{n}".replace /[0-9]/g, (c) -> '۰۱۲۳۴۵۶۷۸۹'[parseInt(c)]

  # Formats a Jalali date into the Bootstrap datepicker format string (e.g. 'dd.mm.yyyy').
  # Tokens are replaced in longest-first order to avoid partial substitution bugs.
  @formatJalaliDate: (jy, jm, jd, format) ->
    pad2 = (n) -> if n < 10 then "0#{n}" else "#{n}"
    p    = App.UiElement.basedate.toPersianDigits
    format
      .replace('yyyy', p(jy))
      .replace('yy',   p(String(jy).slice(-2)))
      .replace('mm',   p(pad2(jm)))
      .replace('dd',   p(pad2(jd)))
      .replace('m',    p(jm))
      .replace('d',    p(jd))

  # Post-processes the rendered Bootstrap datepicker DOM to show Jalali day
  # numbers and a Jalali month/year header. Called after each calendar render.
  @patchJalaliCalendar: (item) ->
    picker = item.find('.datepicker-days')
    return if !picker.length
    dp = item.find('.js-datepicker').data('datepicker')
    return if !dp

    viewYear  = dp.viewDate.getUTCFullYear()
    viewMonth = dp.viewDate.getUTCMonth()  # 0-based

    { jy, jm } = @dateToJalali(viewYear, viewMonth + 1, 15)
    picker.find('.datepicker-switch').text("#{@JALALI_MONTH_NAMES[jm - 1]} #{@toPersianDigits(jy)}")

    prevGy = viewYear; prevGm = viewMonth
    if viewMonth is 0
      prevGm = 12; prevGy = viewYear - 1

    nextGy = viewYear; nextGm = viewMonth + 2
    if nextGm > 12
      nextGm = 1; nextGy = viewYear + 1

    self = @
    picker.find('td.day').each (i, td) ->
      $td = $(td)
      day = parseInt($td.text(), 10)
      return if isNaN(day)
      if $td.hasClass('old')
        { jd } = self.dateToJalali(prevGy, prevGm, day)
      else if $td.hasClass('new')
        { jd } = self.dateToJalali(nextGy, nextGm, day)
      else
        { jd } = self.dateToJalali(viewYear, viewMonth + 1, day)
      $td.text(self.toPersianDigits(jd))

  @render: (attributeConfig) ->
    attribute = $.extend(true, {}, attributeConfig)

    if attribute.name
      attribute.nameRaw = attribute.name
      attribute.name = "{#{@templateName()}}#{attribute.name}"

    item = $( App.view("generic/#{@templateName()}")(
      attribute: attribute
    ) )

    # set our custom template
    $.fn.datepicker.defaults.template = App.view('generic/datepicker')()

    # apply date widgets
    $.fn.datepicker.dates['custom'] = @buildCustomDates()

    @applyPickers(item, attribute)
    @bindEvents(item, attribute)

    item

  @log: (name, args...) ->
    App.Log.debug "Ui.element.#{@templateName()}.#{name}", args...

  @applyPickers: (item, attribute) ->
    isJalali = @isJalali()

    item.find('.js-datepicker').datepicker(
      clearBtn: attribute.null
      weekStart: if isJalali then 6 else 1
      autoclose: true
      todayBtn: 'linked'
      todayHighlight: true
      format: App.i18n.timeFormat()['FORMAT_DATE']
      rtl: App.i18n.dir() is 'rtl'
      container: item
      language: 'custom'
      orientation: attribute.orientation
      disableScroll: attribute.disableScroll
      calendarWeeks: App.Config.get('datepicker_show_calendar_weeks')
    )

    if isJalali
      self   = @
      format = App.i18n.timeFormat()['FORMAT_DATE'] or 'dd.mm.yyyy'
      item.find('.js-datepicker').on 'show changeDate changeMonth changeYear', ->
        setTimeout (-> self.patchJalaliCalendar(item)), 0
      # After the datepicker (and its internal update) finishes, replace the
      # Gregorian text in the visible input with the equivalent Jalali date.
      item.find('.js-datepicker').on 'changeDate', ->
        setTimeout ->
          date = item.find('.js-datepicker').datepicker('getDate')
          return unless date
          gy = date.getFullYear()
          gm = date.getMonth() + 1
          gd = date.getDate()
          { jy, jm, jd } = self.dateToJalali(gy, gm, gd)
          item.find('.js-datepicker').val(self.formatJalaliDate(jy, jm, jd, format))
        , 0

    @setNewTimeInitial(item, attribute)

  # observer changes / update needed to force rerender to get correct today shown
  @bindEvents: (item, attribute) ->
    item
      .find('input')
      .on('focus', (e) ->
        item.find('.js-datepicker').datepicker('rerender')
      ).on('keyup blur change', (e) =>
        @setNewTime(item, attribute, 0)
        @validation(item, attribute, true)
      )

    item.on('validate', (e) =>
      @validation(item, attribute)
    )

  @inputElement: (item, attribute) ->
    if attribute.name
      return item.find("[name=\"#{attribute.name}\"]")
    return item.find('input[type="hidden"]')

  @setNewTime: (item, attribute, tolerant = false) ->
    currentInput = @currentInput(item, attribute)
    return if !currentInput

    if !@validateInput(currentInput)
      @inputElement(item, attribute).val('')
      return

    @inputElement(item, attribute).val(@buildTimestamp(currentInput))

  # returns array with date or false if cannot get date
  @currentInput: (item, attribute) ->
    datetime = item.find('.js-datepicker').datepicker('getDate')
    if !datetime || datetime.toString() is 'Invalid Date'
      @inputElement(item, attribute).val('')
      return false

    @log 'setNewTime', datetime

    year  = datetime.getFullYear()
    month = datetime.getMonth() + 1
    day   = datetime.getDate()
    date  = "#{App.Utils.formatTime(year)}-#{App.Utils.formatTime(month,2)}-#{App.Utils.formatTime(day,2)}"
    [date]

  @validateInput: (currentInput) ->
    currentInput[0] isnt ''

  @buildTimestamp: (currentInput) ->
    throw 'Must override in a subclass'

  @dateSetter: ->
    throw 'Must override in a subclass'

  @setNewTimeInitial: (item, attribute) ->
    timestamp = @inputElement(item, attribute).val()
    @log 'setNewTimeInitial', timestamp
    if !timestamp
      @setNoTimestamp(item)
      return

    timeObject = new Date( Date.parse( timestamp ) )

    @log 'setNewTimeInitial', timestamp, timeObject
    @setTimestamp(item, timeObject)
    item.find('.js-datepicker').datepicker('update')

  @setNoTimestamp: (item) ->
    return

  @setTimestamp: (item, timeObject) ->
    item.find('.js-datepicker').datepicker(@dateSetter(), timeObject)

  @validation: (item, attribute, runtime) ->
    # remove old validation
    if attribute.validationContainer is 'self'
      item.find('.js-datepicker').removeClass('has-error')
    else
      item.closest('.form-group').removeClass('has-error')
      item.find('.has-error').removeClass('has-error')
      item.find('.help-inline').html('')
      item.closest('.form-group').find('.help-inline').html('')

    timestamp = @inputElement(item, attribute).val()

    # check required attributes
    errors = {}
    if !timestamp
      if !attribute.null
        errors[attribute.name] = 'missing'
    else
      timeObject = new Date( Date.parse( timestamp ) )


    @log 'validation', errors
    return if _.isEmpty(errors)

    # show invalid options
    if attribute.validationContainer is 'self'
      item.find('.js-datepicker').addClass('has-error')
    else
      formGroup = item.closest('.form-group')
      for key, value of errors
        formGroup.addClass('has-error')

  @buildCustomDates: ->
    if @isJalali()
      data = {
        days: ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'],
        daysMin: ['ی', 'د', 'سه', 'چ', 'پ', 'ج', 'ش'],
        daysShort: ['ی', 'د', 'سه', 'چ', 'پ', 'ج', 'ش'],
        months: @JALALI_MONTH_NAMES.slice(),
        monthsShort: @JALALI_MONTH_NAMES.slice(),
        today: __('today'),
        clear: __('clear')
      }
      return App.i18n.translateDeepPlain(data)

    data = {
      days: [__('Sunday'), __('Monday'), __('Tuesday'), __('Wednesday'), __('Thursday'), __('Friday'), __('Saturday')],
      daysMin: [__('Sun'), __('Mon'), __('Tue'), __('Wed'), __('Thu'), __('Fri'), __('Sat')],
      daysShort: [__('Sun'), __('Mon'), __('Tue'), __('Wed'), __('Thu'), __('Fri'), __('Sat')],
      months: [__('January'), __('February'), __('March'), __('April'), __('May'), __('June'),
        __('July'), __('August'), __('September'), __('October'), __('November'), __('December')],
      monthsShort: [__('Jan'), __('Feb'), __('Mar'), __('Apr'), __('May'), __('Jun'), __('Jul'), __('Aug'), __('Sep'), __('Oct'), __('Nov'), __('Dec')],
      today: __('today'),
      clear: __('clear')
    }

    App.i18n.translateDeepPlain(data)
