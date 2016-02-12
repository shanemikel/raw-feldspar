-- | Monad for computations in software

module Feldspar.Software.Representation where


import Control.Monad.Operational.Higher
import Control.Monad.Trans

import Language.Embedded.Imperative as Imp hiding (FunArg)

import Feldspar.Representation
import Feldspar.Frontend
import Feldspar.Signatures

--------------------------------------------------------------------------------
-- *
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ** Functions.

data FunctionCMD (exp :: * -> *) (prog :: * -> *) a
  where
    -- ^ ...
    FAdd  :: Signature prog a -> FunctionCMD exp prog (Maybe String)

    -- ^ ...
    FCall :: FName prog a -> FArgument a -> FunctionCMD exp prog (FResult a)

type instance IExp (FunctionCMD e)       = e
type instance IExp (FunctionCMD e :+: i) = e

instance HFunctor (FunctionCMD exp)
  where
    hfmap f (FAdd s)              = FAdd (hfmap f s)
    hfmap f (FCall (FName n s) a) = FCall (FName n (hfmap f s)) a

instance Interp (FunctionCMD exp) IO
  where
    interp = runFunctionCMD

runFunctionCMD :: FunctionCMD exp IO a -> IO a
runFunctionCMD (FAdd _)              = return Nothing -- name not needed for evaluation.
runFunctionCMD (FCall (FName _ s) a) = unroll s a     -- apply arguments.
  where
    unroll :: forall m x. Signature m x -> FArgument x -> m (FResult x)
    unroll (Unit m) (FEmpty)     = m
    unroll (Ret  m) (FEmpty)     = m
    unroll (Lam  f) (a :> as) = unroll (f a) as

--------------------------------------------------------------------------------
-- **

type SoftwareCMD
    =   ControlCMD Data
    :+: PtrCMD     Data
    :+: CallCMD    Data
    :+: ObjectCMD  Data
    :+: FileCMD    Data
    :+: FunctionCMD Data

-- | Monad for computations in software
newtype Software a = Software { unSoftware :: ProgramT SoftwareCMD (Program CompCMD) a }
  deriving (Functor, Applicative, Monad)

instance MonadComp Software
  where
    liftComp        = Software . lift . unComp
    iff c t f       = Software $ Imp.iff c (unSoftware t) (unSoftware f)
    for  range body = Software $ Imp.for range (unSoftware . body)
    while cont body = Software $ Imp.while (unSoftware cont) (unSoftware body)

class Monad m => MonadSoftware m
  where
    liftSoftware :: m a -> Software a

instance MonadSoftware Comp     where liftSoftware = liftComp
instance MonadSoftware Software where liftSoftware = id

--------------------------------------------------------------------------------
