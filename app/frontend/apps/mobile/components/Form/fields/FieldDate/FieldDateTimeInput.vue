<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { VueDatePicker, WeekStart } from '@vuepic/vue-datepicker'
import { useEventListener } from '@vueuse/core'
import { format, formatISO, isValid, parse, parseISO } from 'date-fns'
import { computed, nextTick, ref, toRef, watch } from 'vue'

import useValue from '#shared/components/Form/composables/useValue.ts'
import {
  dateToJalali,
  jalaliMonthLength,
  jalaliToDate,
  jalaliMonthName,
  JALALI_WEEKDAY_SHORT,
  toPersianDigits,
} from '#shared/components/Form/fields/FieldDate/jalali.ts'
import type { DateTimeContext } from '#shared/components/Form/fields/FieldDate/types.ts'
import { useDateFnsLocale } from '#shared/components/Form/fields/FieldDate/useDateFnsLocale.ts'
import { useDateTime } from '#shared/components/Form/fields/FieldDate/useDateTime.ts'
import { usePickerModel } from '#shared/components/Form/fields/FieldDate/usePickerModel.ts'
import { i18n } from '#shared/i18n.ts'
import { useLocaleStore } from '#shared/stores/locale.ts'
import testFlags from '#shared/utils/testFlags.ts'

import '@vuepic/vue-datepicker/dist/main.css'

interface Props {
  context: DateTimeContext
}

const props = defineProps<Props>()

const { dateFnsLocale } = useDateFnsLocale()

const contextReactive = toRef(props, 'context')

const { localValue } = useValue(contextReactive)

const { ariaLabels, displayFormat, is24, maxDate, minDate, timePicker, valueFormat } =
  useDateTime(contextReactive)

const { pickerModel } = usePickerModel(contextReactive, localValue)

// ── Jalali support ────────────────────────────────────────────────────────────

const localeStore = useLocaleStore()
const isJalaliLocale = computed(() => localeStore.localeData?.locale === 'fa-ir')
const isJalaliTextInput = computed(() => isJalaliLocale.value && !timePicker.value)
const weekStart = computed(() => (isJalaliLocale.value ? WeekStart.Saturday : WeekStart.Monday))

const parseValue = (value: string) => {
  if (valueFormat.value === 'iso') return parseISO(value)
  return parse(value, valueFormat.value, new Date())
}

const formatValue = (value: Date) => {
  if (valueFormat.value === 'iso') return formatISO(value)
  return format(value, valueFormat.value)
}

const formatToDisplay = (date: Date): string => {
  const { jy, jm, jd } = dateToJalali(date)
  return `${jy}/${String(jm).padStart(2, '0')}/${String(jd).padStart(2, '0')}`
}

const parseFromDisplay = (value: string): Date => {
  if (!/^\d{4}\/\d{2}\/\d{2}$/.test(value)) return new Date('invalid')

  const [jy, jm, jd] = value.split('/').map(Number)
  if (
    !Number.isInteger(jy) ||
    !Number.isInteger(jm) ||
    !Number.isInteger(jd) ||
    jm < 1 ||
    jm > 12 ||
    jd < 1 ||
    jd > jalaliMonthLength(jy, jm)
  ) {
    return new Date('invalid')
  }

  return jalaliToDate(jy, jm, jd)
}

const navigateJalaliMonth = (
  month: number,
  year: number,
  isNext: boolean,
  updateMonthYear: (m: number, y: number) => void,
) => {
  const midDate = new Date(year, month, 15)
  const { jy, jm } = dateToJalali(midDate)
  let nextJy = jy
  let nextJm = jm + (isNext ? 1 : -1)
  if (nextJm > 12) {
    nextJm = 1
    nextJy++
  }
  if (nextJm < 1) {
    nextJm = 12
    nextJy--
  }
  // Use day 15 so the target date always lands mid-month and is guaranteed
  // to be in a different Gregorian month than day 1 (which can still fall in
  // the current Gregorian month when the Jalali month boundary is late in it).
  const targetDate = jalaliToDate(nextJy, nextJm, 15)
  updateMonthYear(targetDate.getMonth(), targetDate.getFullYear())
}

const getJalaliMonthYearLabel = (month: number, year: number): string => {
  const firstDay = new Date(year, month, 1)
  const lastDay = new Date(year, month + 1, 0)
  const { jy: jy1, jm: jm1 } = dateToJalali(firstDay)
  const { jy: jy2, jm: jm2 } = dateToJalali(lastDay)
  if (jm1 === jm2 && jy1 === jy2) {
    return `${jalaliMonthName(jm1)} ${toPersianDigits(jy1)}`
  }
  if (jy1 !== jy2) {
    return `${jalaliMonthName(jm1)} ${toPersianDigits(jy1)} / ${jalaliMonthName(jm2)} ${toPersianDigits(jy2)}`
  }
  return `${jalaliMonthName(jm1)} / ${jalaliMonthName(jm2)} ${toPersianDigits(jy1)}`
}

// ── Picker visibility ─────────────────────────────────────────────────────────

const config = {
  keepActionRow: true,
  monthChangeOnScroll: false,
}

const rangeConfig = computed(() => {
  if (!props.context.range) return false
  return {
    partialRange: false,
    ...(typeof props.context.range === 'object' ? props.context.range : {}),
  }
})

const actionRow = {
  showSelect: false,
  showCancel: false,
  showNow: true,
  showPreview: false,
  nowBtnLabel: i18n.t('Today'),
}

const input = ref<HTMLInputElement>()
const picker = ref()
const jalaliInputValue = ref('')

const showPicker = ref(false)

const pickerDisplayStyle = computed(() => (showPicker.value ? 'block' : 'none'))

const syncJalaliInputValue = () => {
  if (!isJalaliTextInput.value) {
    jalaliInputValue.value = ''
    return
  }

  if (!localValue.value) {
    jalaliInputValue.value = ''
    return
  }

  if (Array.isArray(localValue.value)) {
    const dates = localValue.value
      .map((value) => (typeof value === 'string' ? parseValue(value) : new Date('invalid')))
      .filter(isValid)

    jalaliInputValue.value = dates.map(formatToDisplay).join(' - ')
    return
  }

  const date = parseValue(localValue.value)
  jalaliInputValue.value = isValid(date) ? formatToDisplay(date) : ''
}

watch([localValue, isJalaliTextInput], syncJalaliInputValue, { immediate: true })

const handleJalaliInput = (event: Event) => {
  const { value } = event.target as HTMLInputElement
  jalaliInputValue.value = value

  if (!value) {
    localValue.value = null
    return
  }

  if (props.context.range) {
    const values = value.split(' - ').map((part) => {
      const date = parseFromDisplay(part)
      if (!isValid(date)) return
      return formatValue(date)
    })

    if (values.length === 2 && values.every(Boolean)) {
      localValue.value = values as string[]
    }

    return
  }

  const date = parseFromDisplay(value)
  if (!isValid(date)) return

  localValue.value = formatValue(date)
}

const handleInput = (event: Event, onInput: (event: Event | string) => void) => {
  if (isJalaliTextInput.value) {
    handleJalaliInput(event)
    return
  }

  onInput(event)
}

const handlePaste = (event: ClipboardEvent, onPaste: (event: ClipboardEvent) => void) => {
  if (isJalaliTextInput.value) return
  onPaste(event)
}

const handleBlur = (event: FocusEvent, onBlur: (event: FocusEvent) => void) => {
  if (isJalaliTextInput.value) {
    syncJalaliInputValue()
  }

  onBlur(event)
}

const handleEnter = (event: KeyboardEvent, onEnter: (event: KeyboardEvent) => void) => {
  if (isJalaliTextInput.value) {
    syncJalaliInputValue()
    return
  }

  onEnter(event)
}

const handleTab = (event: KeyboardEvent, onTab: (event: KeyboardEvent) => void) => {
  if (isJalaliTextInput.value) {
    syncJalaliInputValue()
    return
  }

  onTab(event)
}

const expandPicker = () => {
  showPicker.value = true

  nextTick(() => {
    testFlags.set(`field-date-time-${props.context.id}.opened`)
  })
}

const collapsePicker = () => {
  showPicker.value = false

  nextTick(() => {
    testFlags.set(`field-date-time-${props.context.id}.closed`)
  })
}

useEventListener('click', (e) => {
  const { target } = e

  if (!target || !picker.value || !showPicker.value || !input.value) return

  const outer = (target as Element).closest('.formkit-outer')
  if (!outer) return

  const insideFormField = !outer.contains(target as Node)
  if (insideFormField) return

  collapsePicker()
})
</script>

<template>
  <div class="flex w-full">
    <!-- eslint-disable vuejs-accessibility/aria-props -->
    <VueDatePicker
      ref="picker"
      v-model="pickerModel"
      :class="{ 'pointer-events-none': context.disabled }"
      :model-type="valueFormat"
      :disabled="context.disabled"
      :range="rangeConfig"
      :partial-range="context.partialRange"
      :time-config="{
        enableTimePicker: timePicker,
        is24: is24,
        ignoreTimeValidation: !timePicker,
      }"
      :formats="displayFormat"
      :locale="dateFnsLocale"
      :max-date="maxDate"
      :min-date="minDate"
      :start-date="minDate || maxDate"
      :prevent-min-max-navigation="
        Boolean(minDate || maxDate || context.futureOnly || context.pastOnly)
      "
      :action-row="actionRow"
      :config="config"
      :aria-labels="ariaLabels"
      :inline="{ input: true }"
      :text-input="{ openMenu: 'toggle', format: displayFormat.input }"
      :input-attrs="{
        id: context.id,
        name: context.node.name,
        clearable: !!context.clearable,
      }"
      :week-start="weekStart"
      auto-apply
      dark
      @open="expandPicker"
      @close="collapsePicker"
      @blur="context.handlers.blur"
    >
      <!-- Jalali calendar header: weekday abbreviations (Sat…Fri) -->
      <template #calendar-header="{ day, index }">
        {{ isJalaliLocale ? JALALI_WEEKDAY_SHORT[index] : day }}
      </template>

      <!-- Jalali month/year header with Jalali-aware prev/next navigation.
           The mode === 'date' guard narrows the union type to DatePickerMonthYearSlotProps. -->
      <template #month-year="rawProps">
        <template v-if="rawProps.mode === 'date'">
          <div v-if="isJalaliLocale" class="dp--month-year-wrap">
            <button
              type="button"
              class="dp--btn dp--inner-nav dp--arrow-btn-nav"
              :aria-label="ariaLabels.nextMonth"
              :disabled="rawProps.isDisabled(true)"
              @click="navigateJalaliMonth(rawProps.month, rawProps.year, true, rawProps.updateMonthYear)"
            >
              <CommonIcon name="chevron-left" size="xs" decorative />
            </button>
            <span class="dp--month-year-select font-medium">
              {{ getJalaliMonthYearLabel(rawProps.month, rawProps.year) }}
            </span>
            <button
              type="button"
              class="dp--btn dp--inner-nav dp--arrow-btn-nav"
              :aria-label="ariaLabels.prevMonth"
              :disabled="rawProps.isDisabled(false)"
              @click="navigateJalaliMonth(rawProps.month, rawProps.year, false, rawProps.updateMonthYear)"
            >
              <CommonIcon name="chevron-right" size="xs" decorative />
            </button>
          </div>
          <div v-else class="dp--month-year-wrap">
            <button
              type="button"
              class="dp--btn dp--inner-nav dp--arrow-btn-nav"
              :disabled="rawProps.isDisabled(false)"
              @click="rawProps.handleMonthYearChange(false)"
            >
              <CommonIcon name="chevron-left" size="xs" decorative />
            </button>
            <button type="button" class="dp--btn dp--month-year-select">
              {{ rawProps.months[rawProps.month]?.text }}
            </button>
            <button type="button" class="dp--btn dp--year-select">
              {{ rawProps.year }}
            </button>
            <button
              type="button"
              class="dp--btn dp--inner-nav dp--arrow-btn-nav"
              :disabled="rawProps.isDisabled(true)"
              @click="rawProps.handleMonthYearChange(true)"
            >
              <CommonIcon name="chevron-right" size="xs" decorative />
            </button>
          </div>
        </template>
      </template>

      <!-- Jalali day numbers in each calendar cell -->
      <template #day="{ date, day }">
        <span v-if="isJalaliLocale">{{ toPersianDigits(dateToJalali(date).jd) }}</span>
        <span v-else>{{ day }}</span>
      </template>

      <template #dp-input="{ value, onInput, onEnter, onTab, onBlur, onKeypress, onPaste }">
        <input
          :id="context.id"
          ref="input"
          :value="isJalaliTextInput ? jalaliInputValue : value"
          :name="context.node.name"
          :class="context.classes.input"
          :aria-describedby="context.describedBy"
          :disabled="context.disabled"
          type="text"
          v-bind="context.attrs"
          @input="handleInput($event, onInput)"
          @keydown.enter="handleEnter($event, onEnter)"
          @keydown.tab="handleTab($event, onTab)"
          @keydown="onKeypress"
          @paste="handlePaste($event, onPaste)"
          @blur="handleBlur($event, onBlur)"
          @focus="expandPicker"
        />
        <div v-if="showPicker" class="w-full" :class="{ 'pe-2': context.link }">
          <div class="h-px w-full bg-white/10" />
        </div>
      </template>
      <template #clear-icon>
        <CommonIcon
          class="absolute -mt-5 shrink-0 text-gray ltr:right-2 rtl:left-2"
          :aria-label="i18n.t('Clear selection')"
          name="close-small"
          size="base"
          role="button"
          tabindex="0"
          @click.stop="picker?.clearValue()"
          @keypress.space.prevent.stop="picker?.clearValue()"
        />
      </template>
      <template #clock-icon>
        <CommonIcon name="clock" size="tiny" decorative />
      </template>
      <template #calendar-icon>
        <CommonIcon name="calendar" size="tiny" decorative />
      </template>
      <template #arrow-left>
        <CommonIcon name="chevron-left" size="xs" decorative />
      </template>
      <template #arrow-right>
        <CommonIcon name="chevron-right" size="xs" decorative />
      </template>
      <template #arrow-up>
        <CommonIcon name="chevron-up" size="xs" decorative />
      </template>
      <template #arrow-down>
        <CommonIcon name="chevron-down" size="xs" decorative />
      </template>
    </VueDatePicker>
  </div>
</template>

<style scoped>
:deep(.dp--outer-menu-wrap) .dp--menu {
  /* stylelint-disable value-keyword-case */
  display: v-bind(pickerDisplayStyle);
  max-width: var(--dp-menu-min-width);
  margin: 0 auto;
}

:deep(.dp--theme-dark) {
  --dp-background-color: var(--color-gray-500);
  --dp-text-color: var(--color-white);
  --dp-hover-color: transparent;
  --dp-hover-text-color: var(--color-white);
  --dp-hover-icon-color: var(--color-white);
  --dp-primary-color: var(--color-blue);
  --dp-secondary-color: var(--color-gray-200);
  --dp-border-color: transparent;
  --dp-menu-border-color: transparent;
  --dp-border-color-hover: transparent;
  --dp-range-between-dates-background-color: var(--color-blue-highlight);
  --dp-range-between-dates-text-color: var(--color-white);
  --dp-range-between-border-color: transparent;

  &:where([data-errors='true'] *),
  &:where([data-invalid='true'] *) {
    --dp-background-color: var(--color-red-dark);
  }
}

:deep(.dp--main) {
  --dp-font-family: var(--default-font-family);
  --dp-border-radius: 0.375rem;
  --dp-cell-border-radius: 9999px;
  --dp-button-height: 2rem;
  --dp-action-button-height: 2rem;
  --dp-month-year-row-height: 2rem;
  --dp-month-year-row-button-size: 2rem;
  --dp-common-padding: 0.5rem;
  --dp-action-row-padding: 0.5rem;
  --dp-menu-min-width: 260px;
  --dp-font-size: 1rem;
  --dp-preview-font-size: 1rem;
  --dp-time-font-size: 1.25rem;

  &,
  & > div {
    width: 100%;
  }

  .dp--button,
  .dp--action-button {
    border: none;
    color: var(--color-white);
    background: var(--color-gray-200);
  }

  .dp--clear-btn {
    top: 2.3rem;
  }

  .dp--tp-wrap {
    padding: var(--dp-common-padding);
    max-width: none;
  }

  .dp--btn,
  .dp--button,
  .dp--calendar-item,
  .dp--action-button {
    transition: none;
    border-radius: 0.375rem;
  }

  .dp--action-buttons {
    margin-inline-start: 0;
    flex-grow: 1;
  }

  .dp--action-button {
    margin-inline-start: 0;
    transition: none;
    flex-grow: 1;
    display: inline-flex;
    justify-content: center;
    border-radius: 0.375rem;
  }

  .dp--action-cancel {
    border: none;
  }

  .dp--arrow-btn-nav .dp--inner-nav {
    color: var(--color-blue);
  }

  .dp--overlay-container {
    padding-bottom: 0.5rem;
  }

  .dp--overlay-container + .dp--button,
  .dp--overlay-row + .dp--button {
    width: auto;
    margin: 0.5rem;
  }

  .dp--overlay-container + .dp--button:not(.dp--overlay-action) {
    width: calc(var(--dp-menu-min-width) - 0.375rem * 2);
  }

  .dp--overlay-container + .dp--button.dp--overlay-action {
    width: calc(var(--dp-menu-min-width) - 0.625rem * 2);
  }

  .dp--calendar-header-item {
    padding-left: 0;
    padding-right: 0;
  }
}
</style>
