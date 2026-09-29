import pandas as pd
import datetime as datetime
import requests
from math import floor
import json
import yahoo_fin.stock_info as si
import yfinance as yf 
from yahoo_finance import Share
import yahoo_fin
import ssl
ssl._create_default_https_context = ssl._create_stdlib_context



import datetime as datetime
start_date = (datetime.date.today() + datetime.timedelta(days=-2)).strftime(
       "%m/%d/%Y"
   )  # Input format is: month/day/Year
end_date = (datetime.date.today() + datetime.timedelta(days=1)).strftime("%m/%d/%Y")

def get_lists():
    # listing names 
    # market cap
    # wleocme
    # percentage change 

    # shortname 
    return []

def cron_job():
    # return []
    return "1"

def get_latest_news():
    return []

x ={
    "listing name" : "",
    "capitalisation":"",
    "symbol":"",
    "percentage_change":"",
    "action":"get financials"
}


def get_tickers():
    tickers = []

    return tickers
# repetition to the do the same task depedent o timer = 


def play_with_tickers():
    msft = yf.Ticker("msft")
    # new_dict = {}
    # new_dict['ticker'] = yahoo.get_open()
    print(msft.history(period='1d').Open[0])
    # print(msft.info["companyOfficers"][0]['name'])

# play_with_tickers()

# timer_variability = datetime.time()
# def function_that_reoccurs():
#     return 1

# print("strict",si.tickers_nasdaq())
# print("xxx",si.tickers_nasdaq())

# extract the listing name
# extract the users companies and their open 
# market_Capp = # sum the list together 
def get_ticker_list(grouped_stocks):
  if grouped_stocks == 'dow':
    ticker_list = si.tickers_dow()

  elif grouped_stocks == 'sp500':
    sp500_url_link = "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
    data_table = pd.read_html(sp500_url_link)
    ticker_list = data_table[0]['Symbol'].tolist()

  elif grouped_stocks == 'nasdaq':
    ticker_list = si.tickers_nasdaq()

  else:
    ticker_list = "Input group of stocks not recognised"
  return ticker_list

def get_market_capitalisation(x):
      sum_list=[]
      market_capitalisation = 0
      market = dict()
      # for a in x:
      #     msft = yf.Ticker(a)
      #     he.append(msft.history(period='1d').Open.values)
      # market_capitalisation=sum(he)
      for i in x:
        try:
          if i == "BRK.B":
            print("issues with brk.b")
            pass
          market[i] =si.get_data(i, start_date, end_date, index_as_date=True, interval="1d").open.values
          print(i, market[i])
        except AssertionError:
          continue
        except Exception:
           continue

      for values in zip(*market.values()):
        sum_list.append(sum(values))
      
      print("sum_list", format(sum(sum_list), '.2f'))
      return format(sum(sum_list), '.2f')


def difference_in_change(microsoft):
    x=0
    msft = yf.Ticker(microsoft)
    values = msft.history(period='2d').Open.values
    x = values[1] - values[0]

    data = dict()
    data['market_cap'] = values[0]
    data['change'] = x

    return data

def getting_market_cap(group_stocks):
   return get_market_capitalisation(get_ticker_list(group_stocks))

# print(getting_market_cap('sp500'))
# getting_market_cap('dow')
# difference_in_change("msft")


# get_market_capitalisation(get_ticker_list("sp500"))
# print(get_ticker_list("sp500"))
# play with dow




# create a response cache sheet to json and cron job 