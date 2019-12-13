class BillScrapeJob < ApplicationJob

  def perform(fpl_account)
    if Rails.env.production?
      args = %w[--disable-infobars --headless window-size=1600,1200 --no-sandbox --disable-gpu]
      options = {
         binary: ENV['GOOGLE_CHROME_BIN'],
         prefs: { password_manager_enable: false, credentials_enable_service: false },
         args:  args
      }
      browser = Watir::Browser.new :chrome, options: options
    else
      browser = Watir::Browser.new :chrome, headless: true
    end
    browser.goto "http://fpl.com"
    browser.input(name: "username").send_keys(fpl_account.username)
    browser.input(name: "password").send_keys(fpl_account.password, :return)
    sleep 5
    browser.element(text: "Visit Energy Dashboard").click
    sleep 5
    zipcode = browser.tds(id: "accServiceAddress").map(&:text).reject(&:empty?).pop.last(5)
    fpl_account.update(zipcode: zipcode) if fpl_account.zipcode != zipcode
    magic_script = browser.scripts.find{|s| s.html.include?('Billing Period')}.html
    regex = /Billing Period: (.*?) to (.*?){br}Bill Amount: \$(.*?){br}Billed kWh: (.*?) kWh/
    magic_script.scan(regex) do |start_date, end_date, bill_amount, kWh|
      fpl_account.bills.find_or_create_by(
        start_date:     Date.parse(start_date),
        end_date:       Date.parse(end_date),
        kilowatt_hours: kWh,
        amount_cents:   (bill_amount.to_f * 100).to_i
      )
    end
    Sync.create(fpl_account: fpl_account)
    BillScrapeChannel.broadcast_to(fpl_account.user, { refetch_bills: true })
    browser.close
    GC.start
  end

end


# Redis, selenium, watir, active job, action cable
