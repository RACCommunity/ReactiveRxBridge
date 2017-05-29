import Result
import ReactiveSwift
import RxSwift

fileprivate struct RxObserver<Value>: ObserverType {
    let observer: Signal<Value, AnyError>.Observer

    init(_ observer: Signal<Value, AnyError>.Observer) {
        self.observer = observer
    }

    func on(_ event: RxSwift.Event<Value>) {
        switch event {
        case let .next(value):
            observer.send(value: value)
        case let .error(error):
            observer.send(error: AnyError(error))
        case .completed:
            observer.sendCompleted()
        }
    }
}

// - MARK: Bridging from Rx.
// Use ReactiveSwift API conventions and Swift API Guidelines.

extension SignalProducer where Error == AnyError {
    public init(_ observable: Observable<Value>) {
        self.init { observer, lifetime in
            let rxDisposable = observable.subscribe(RxObserver(observer))
            lifetime.observeEnded(rxDisposable.dispose)
        }
    }
}

extension Signal where Error == AnyError {
    public convenience init(_ observable: Observable<Value>) {
        self.init { observer in
            let rxDisposable = observable.subscribe(RxObserver(observer))
            return AnyDisposable(rxDisposable.dispose)
        }
    }
}

extension Variable: PropertyProtocol {
    public var producer: SignalProducer<Element, NoError> {
        return SignalProducer(asObservable())
            .flatMapError { _ in .empty }
    }

    public var signal: Signal<Element, NoError> {
        return Signal(asObservable())
            .flatMapError { _ in .empty }
    }
}

// - MARK: Bridging to Rx.
// Use RxSwift API conventions.

extension Signal: ObservableConvertibleType {
    public func asObservable() -> Observable<Value> {
        return SignalProducer(self).asObservable()
    }
}

extension SignalProducer: ObservableConvertibleType {
    public func asObservable() -> Observable<Value> {
        return Observable.create { observer in
            let interruptHandle = self.start { event in
                switch event {
                case let .value(value):
                    observer.onNext(value)
                case let .failed(error):
                    observer.onError(error)
                case .completed, .interrupted:
                    observer.onCompleted()
                }
            }

            return RxSwift.Disposables
                .create(with: interruptHandle.dispose)
        }
    }
}

extension Property: ObservableConvertibleType {}
extension MutableProperty: ObservableConvertibleType {}

extension PropertyProtocol {
    public func asObservable() -> Observable<Value> {
        return producer.asObservable()
    }
}
