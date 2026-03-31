# Настройки
ERLC = erlc
ERL = erl
OUT_DIR = ebin

# Поиск всех исходников в обеих папках
GOODS_SRCS = $(wildcard goods/src/*.erl)
GOODS_TESTS = $(wildcard goods/test/*.erl)
GOODS_OUT = goods/ebin
MISULTIN_SRCS = $(wildcard misultin/src/*.erl)
MISULTIN_OUT = misultin/ebin
GPROC_SRCS = $(wildcard gproc/src/*.erl)
GPROC_OUT = gproc/ebin
JSX_SRCS = $(wildcard jsx/src/*.erl)
JSX_OUT = jsx/ebin
#MAKE = make

ERL_OPTS = -pa goods/ebin -pa misultin/ebin -pa gproc/ebin -pa jsx/ebin -pa cowboy/ebin -pa ranch/ebin -pa cowlib/ebin

all: compile

deps:
	$(MAKE) -C ranch
	$(MAKE) -C cowlib
	$(MAKE) -C cowboy ERLC_OPTS="-I $(CURDIR)/ranch/include -pa $(CURDIR)/ranch/ebin -pa $(CURDIR)/cowlib/ebin"

compile: deps
	$(ERLC) -I misultin/include -I misultin/src -o $(MISULTIN_OUT) $(MISULTIN_SRCS)
	$(ERLC) -I gproc/include -o $(GPROC_OUT) $(GPROC_SRCS)
	$(ERLC) -I jsx/include -o $(JSX_OUT) $(JSX_SRCS)
	$(ERLC) -I goods/include -o $(GOODS_OUT) $(GOODS_SRCS)
	@echo "Компиляция завершена."

compile-tests:
	$(ERLC) -DTEST -I goods/include -o $(GOODS_OUT) $(GOODS_TESTS)

# Запуск приложения
run-app: compile
	erl $(ERL_OPTS) \
		-kernel logger_level info \
		-eval "application:ensure_all_started(gproc), \
		       application:ensure_all_started(inets), \
		       application:ensure_all_started(ssl), \
			   application:ensure_all_started(cowboy), \
		       application:start(goods_app)."

# тестировалось на локальном сервере, для этого использовал параметр перед eval
# 		-goods_app url '"http://localhost:6666"' \
# в случае проблем с загрузкой (роскомнадзор давит клаудфронт) и использованием средст обхода  DPI добавить следующий параметр
#		-goods_app partial true \

#Запуск тестов
tests: compile-tests
	$(ERL) -noshell $(ERL_OPTS)  -eval "eunit:test({dir, \"$(GOODS_OUT)\"}), init:stop()."

clean:
	rm -rf $(OUT_DIR) *.beam