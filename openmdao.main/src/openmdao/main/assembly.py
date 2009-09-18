
#public symbols
__all__ = ['Assembly']



import os.path

from enthought.traits.api import implements, Array, List, Instance, TraitError
from enthought.traits.api import TraitType, Undefined
from enthought.traits.trait_base import not_none

import networkx as nx

from openmdao.main.interfaces import IDriver
from openmdao.main.component import Component
from openmdao.main.workflow import Workflow
from openmdao.main.dataflow import Dataflow
from openmdao.main.util import filexfer
from openmdao.main.filevar import FileValue

class MulticastTrait(TraitType):
    """A trait with a list of destination attributes (with names evaluated in
    the scope of the instance object containing the trait)
    that are set whenever the attribute corresponding to this trait is set.
    """
    
    def init(self):
        self.names = self._metadata.get('names', [])
        self.val_trait = self._metadata.get('val_trait', None)            

    def validate(self, obj, name, value):
        if self.val_trait:
            val = self.val_trait.validate(obj, name, value)
        else:
            msg = ("No validating trait has been specified when creating "+
                  "Multicast trait '%s'" % name)
            raise TraitError(msg)
        return val
    
    def post_setattr(self, obj, name, value):
        if value is not Undefined:
            for vname in self.names:
                try:
                    obj.set(vname, value, srcname=name)
                except Exception, exc:
                    msg = "cannot set '%s' from '%s': %s" % \
                        (vname, name, exc)
                    obj.raise_exception(msg, type(exc))
                
        
class Assembly (Component):
    """This is a container of Components. It understands how
    to connect inputs and outputs between its children 
    and how to run a Workflow.
    """
    drivers = List(IDriver)
    workflow = Instance(Workflow)
    
    def __init__(self, doc=None, directory='', workflow=None):
        self._stop = False
        self._dir_stack = []
        self._child_io_graphs = {}
        self._need_child_io_update = True
        
        # A graph of Variable names (local path), 
        # with connections between Variables as directed edges.  
        # Children are queried for dependencies between their inputs and outputs
        # so they can also be represented in the graph. 
        self._var_graph = nx.DiGraph()
        
        super(Assembly, self).__init__(doc=doc, directory=directory)
        
        # add any Variables we may have inherited from our base classes
        # to our _var_graph..
        for v in self.keys(iostatus=not_none):
            if v not in self._var_graph:
                self._var_graph.add_node(v)
        
        if workflow is None:
            self.workflow = Dataflow(scope=self)
        else:
            self.workflow = workflow
            workflow.scope = self

        # List of meta-data dictionaries.
        self.external_files = []

    def get_component_graph(self):
        """Retrieve the dataflow graph of child components."""
        return self.workflow.get_graph()
    
    def get_var_graph(self):
        """Returns the Variable dependency graph, after updating it with child
        info if necessary.
        """
        if self._need_child_io_update:
            vargraph = self._var_graph
            childiographs = self._child_io_graphs
            for childname,val in childiographs.items():
                graph = getattr(self, childname).get_io_graph()
                if graph is not val:  # child io graph has changed
                    if val is not None:  # remove old stuff
                        vargraph.remove_nodes_from(val)
                    childiographs[childname] = graph
                    vargraph.add_nodes_from(graph.nodes_iter())
                    vargraph.add_edges_from(graph.edges_iter())
            self._need_child_io_update = False
        return self._var_graph
        
    #def get_io_graph(self):
        #"""For now, just return our base class version of get_io_graph."""
        ## TODO: make this return an actual graph of inputs to outputs based on 
        ##       the contents of this Assembly instead of a graph where all outputs
        ##       depend on all inputs
        ## NOTE: if the io_graph changes, this function must return a NEW graph
        ## object instead of modifying the old one, because object identity
        ## is used in the parent assembly to determine of the graph has changed
        #return super(Assembly, self).get_io_graph()
    
    def add_container(self, name, obj):
        """Update dependency graph and call base class add_container.
        Returns the added Container object.
        """
        obj = super(Assembly, self).add_container(name, obj)
        if isinstance(obj, Component):
            # This is too early to get accurate Variable info from 
            # the child since it's __init__ function may not be complete
            # yet (in the case of auto-registration by the Container base class),
            # so just put a None entry in the _child_io_graphs dict and fill
            # it in later
            self._child_io_graphs[obj.name] = None
            self._need_child_io_update = True
            self.workflow.add_node(obj.name)
        try:
            self.drivers.append(obj)  # will fail if it's not an IDriver
        except TraitError:
            pass
        return obj
        
    def remove_container(self, name):
        """Remove the named object from this container and notify any observers.
        """
        if '.' in name:
            self.raise_exception('remove_container does not allow dotted path names like %s' %
                                 name, ValueError)
        trait = self.trait(name)
        if trait is not None and trait.is_trait_type(Instance):
            setattr(self, name, None)
            return
            
        obj = self.get(name)
        if isinstance(obj, Component):
            self.workflow.remove_node(obj.name)
            if name in self._child_io_graphs:
                childgraph = self._child_io_graphs[name]
                if childgraph is not None:
                    self._var_graph.remove_nodes_from(childgraph)
                del self._child_io_graphs[name]
        
            if obj in self.drivers:
                self.drivers.remove(obj)
        else:
            self.raise_exception('attribute %s is not a Component' % name,
                                 RuntimeError)
            
        for drv in self.drivers:
            drv.graph_regen_needed()

    def create_passthru(self, traitname, alias=None):
        """Create a trait that's a copy of the named trait, add it to self,
        and create a passthru connection between it and var.  If alias is not
        None, the name of the 'promoted' trait will be the alias.
        """
        # check to see if var is already connected
        if self.is_destination(traitname):
            self.raise_exception('%s is already connected' % 
                                 traitname, RuntimeError) 

        # traitname must have at least two parts
        compname, vname = traitname.split('.', 1)
        comp = getattr(self, compname)
        name = alias or vname
        
        # make sure name isn't a dotted path
        if '.' in name:
            self.raise_exception('%s must be a simple name, not a dotted path' %
                                 name)
            
        # check to see if a trait already exists with the given traitname
        if name in self.__dict__:
            self.raise_exception('%s is already a public Variable' % name, 
                                 RuntimeError) 
        
        # Check if existing trait is a property.
        currtrait = comp.trait(vname)
        if not currtrait:
            try:
                comp.make_public(vname, iostatus=None)
                currtrait = comp.trait(vname)
            except Exception, exc:
                pass
        if not currtrait:
                self.raise_exception("cannot find trait named '%s' in component '%s'" %
                                     (vname, compname), TraitError)
        iostatus = currtrait.iostatus
        try:
            if iostatus == 'in':
                prop = currtrait.trait_type.set
            elif iostatus == 'out':
                prop = currtrait.trait_type.get
            else:
                self.raise_exception('unknown iostatus %s' % iostatus)
        except AttributeError:
            prop = None

        default = getattr(comp, vname)

        # If property, make a corresponding plain trait, else just copy.
        if prop:
            trait = currtrait.trait_type.trait
            try:
                if isinstance(trait, Array):
                    comptrait = Array(trait.dtype, shape=trait.shape,
                                      desc=currtrait.desc, iostatus=iostatus)
                else:
                    comptrait = trait.__class__(default, desc=currtrait.desc,
                                                iostatus=iostatus)
            except TraitError, exc:
                self.raise_exception("can't create passthru trait for %s:%s: %s"
                                     % (compname, vname, exc), TraitError)
        else:
            comptrait = comp.trait(vname, copy=True)

        # create the passthru connection 
        if iostatus == 'in':
            self.add_trait(name, MulticastTrait(default_value=default,
                                                val_trait=comptrait,
                                                names=[traitname],
                                                iostatus=iostatus))
            setattr(self, name, default)
            self.connect(name, traitname)
        else:
            self.add_trait(name, comptrait)
            setattr(self, name, default)
            self.connect(traitname, name)
        self.set_valid(name, comp.get_valid(vname))
        
    def split_varpath(self, path):
        """Return a tuple of compname,component,varname given a path
        name of the form 'compname.varname'. If the name is of the form 'varname'
        then compname will be None and comp is self. 
        """
        try:
            compname, varname = path.split('.', 1)
        except ValueError:
            return (None, self, path)
        
        return (compname, getattr(self, compname), varname)

    def connect(self, srcpath, destpath):
        """Connect one src Variable to one destination Variable. This could be
        a normal connection (output to input) or a passthru connection."""

        srccompname, srccomp, srcvarname = self.split_varpath(srcpath)
        srctrait = srccomp.get_dyn_trait(srcvarname, 'out')
        destcompname, destcomp, destvarname = self.split_varpath(destpath)
        desttrait = destcomp.get_dyn_trait(destvarname, 'in')
        
        if srccompname == destcompname:
            self.raise_exception('Cannot connect %s to %s. Both are on same component.' %
                                 (srcpath, destpath), RuntimeError)
        if srccomp is self or destcomp is self: # it's a passthru connection
            if srccomp is destcomp:
                self.raise_exception('Cannot connect "%s" to "%s" on same component' %
                                      (srcvarname, destvarname), RuntimeError)
        else: # it's not a passthru connection so must connect output to input
            if srctrait.iostatus != 'out':
                self.raise_exception('.'.join([srccomp.get_pathname(),srcvarname])+
                                     ' must be an output variable',
                                     RuntimeError)
            if desttrait.iostatus != 'in':
                self.raise_exception('.'.join([destcomp.get_pathname(),destvarname])+
                                     ' must be an input variable',
                                     RuntimeError)
        if self.is_destination(destpath):
            self.raise_exception(destpath+' is already connected',
                                 RuntimeError)             
            
        # test compatability (raises TraitError on failure)
        desttrait.validate(destcomp, destvarname, 
                           getattr(srccomp, srcvarname))
        
        if destcomp is not self:
            destcomp.set_source(destvarname, srcpath)
            if srccomp is not self: # neither var is on boundary
                if hasattr(self.workflow, 'connect'):
                    self.workflow.connect(srccompname, destcompname, 
                                           srcvarname, destvarname)
        
        vgraph = self.get_var_graph()
        vgraph.add_edge(srcpath, destpath)
            
        # invalidate destvar if necessary
        if destcomp is self and desttrait.iostatus == 'out': # boundary output
            if destcomp.get_valid(destvarname) and srccomp.get_valid(srcvarname) is False:
                if self.parent:
                    # tell the parent that anyone connected to our boundary
                    # output is invalid.
                    # Note that it's a dest var in this scope, but a src var in
                    # the # parent scope.
                    self.parent.invalidate_deps([destpath], True)
            self.set_valid(destpath, False)
        elif srccomp is self and srctrait.iostatus == 'in': # boundary input
            self.set_valid(srcpath, False)
        else:
            destcomp.set_valid(destvarname, False)
            self.invalidate_deps([destpath])
        
        self._io_graph = None

        for drv in self.drivers:
            drv.graph_regen_needed()

    def _filter_internal_edges(self, edges):
        """Return a copy of the given list of edges with edges removed that are
        connecting two variables on the same component.
        """
        return [(u,v) for u,v in edges
                              if u.split('.', 1)[0] != v.split('.', 1)[0]]
    
    def disconnect(self, varpath, varpath2=None):
        """Remove all connections to/from a given variable in the current scope.
        This does not remove connections to boundary Variables from the parent
        scope.
        """
        vargraph = self.get_var_graph()
        if varpath not in vargraph:
            tup = varpath.split('.', 1)
            if len(tup) == 1 and isinstance(getattr(self, varpath), Component):
                comp = getattr(self, varpath)
                for var in comp.list_inputs():
                    self.disconnect('.'.join([varpath, var]))
                for var in comp.list_outputs():
                    self.disconnect('.'.join([varpath, var]))
            else:
                self.raise_exception("'%s' is not a linkable attribute" %
                                     varpath, RuntimeError)
            return
        
        to_remove = []
        if varpath2 is not None:
            if varpath2 in vargraph[varpath]:
                to_remove.append(varpath, varpath2)
            elif varpath in vargraph[varpath2]:
                to_remove.append(varpath2, varpath)
            else:
                self.raise_exception('%s is not connected to %s' % 
                                     (varpath, varpath2), RuntimeError)
        else:  # remove all connections from the Variable
            # remove outgoing edges
            to_remove = []
            for u,v in vargraph.edges_iter(varpath):
                to_remove.append((u,v))
            # remove incoming edges
            for u,v in vargraph.in_edges_iter(varpath):
                to_remove.append((u,v))
        
        for u,v in self._filter_internal_edges(to_remove):
            vtup = v.split('.', 1)
            if len(vtup) > 1:
                getattr(self, vtup[0]).remove_source(vtup[1])
                # if its a connection between two children (no boundary connections)
                # then remove a connection between two components in the component
                # graph
                utup = u.split('.',1)
                if len(utup)>1 and hasattr(self.workflow, 'disconnect'):
                    self.workflow.disconnect(utup[0], vtup[0])
                
            vargraph.remove_edges_from(to_remove)
                
        self._io_graph = None  # the io graph has changed, so have to remake it
        for drv in self.drivers:
            drv.graph_regen_needed()


    def is_destination(self, varpath):
        """Return True if the Variable specified by varname is a destination
        according to our graph. This means that either it's an input connected
        to an output, or it's the destination part of a passtru connection.
        """
        tup = varpath.split('.',1)
        preds = self._var_graph.pred.get(varpath, {})
        if len(tup) == 1:
            return len(preds) > 0
        else:
            start = tup[0]+'.'
            for pred in preds:
                if not pred.startswith(start):
                    return True
        return False

    def execute (self):
        """By default, run child components in data flow order."""
        self.workflow.run()
        self._update_boundary_vars()
        
    def _update_boundary_vars (self):
        """Update output variables on our bounary."""
        invalid_outs = self.list_outputs(valid=False)
        vgraph = self.get_var_graph()
        for out in invalid_outs:
            inedges = vgraph.in_edges(nbunch=out)
            if len(inedges) > 1:
                self.raise_exception("attribute '%s' has multiple inputs (%s)" %
                                     (out, [x[1] for x in inedges]),
                                     RuntimeError)
            elif len(inedges) == 1:
                setattr(self, out, self.get(inedges[0][0]))
        
    def step(self):
        """Execute a single child component and return."""
        self.workflow.step()
    
    def list_connections(self, show_passthru=True):
        """Return a list of tuples of the form (outvarname, invarname).
        """
        conns = []
        graph = self.get_var_graph()
        for outname, inname in graph.edges_iter():
            if '.' in outname or '.' in inname:
                if show_passthru:
                    conns.append((outname, inname))
            else:
                conns.append((outname, inname))
        return self._filter_internal_edges(conns)

    def update_inputs(self, compname, varnames):
        """Transfer input data to input variables on the specified component.
        If varnames is not None, only the variables in the list will be updated.
        Note that we're called after incomp has set its execution directory,
        so we'll need to account for this during file transfers. The varnames
        iterator is assumed to contain names that include the component name,
        for example: ['comp1.a', 'comp1.b'].
        """
        updated = False  # this becomes True if we actually update any inputs
        parent = self.parent
        vargraph = self.get_var_graph()
        pred = vargraph.pred
        if compname is None:
            comp = self
        else:
            comp = getattr(self, compname)
        
        for vname in varnames:
            preds = pred.get(vname, '')
            if len(preds) == 0: 
                continue
            elif len(preds) > 1:
                self.raise_exception("variable '%s' has multiple sources %s" %
                                     (vname, preds.keys()), RuntimeError)
                
            updated = True
            srcname = preds.keys()[0]
            srccompname,srccomp,srcvarname = self.split_varpath(srcname)
            destcompname,destcomp,destvarname = self.split_varpath(vname)
            
            if srccomp.get_valid(srcvarname) is False:  # source is invalid 
                # need to backtrack to get a valid source value
                if srccompname is None: # a boundary var
                    if parent:
                        parent.update_inputs(self.name,
                                             ['.'.join([self.name, srcname])])
                    else:
                        srccomp.set_valid(srcvarname, True) # validate source
                else:
                    srccomp.update_outputs([srcvarname])

            try:
                srcval = srccomp.get_wrapped_attr(srcvarname)
            except Exception, err:
                self.raise_exception("cannot retrieve value of source attribute '%s'" %
                                     srcname, type(err))
            
            if isinstance(srcval, FileValue):
                if comp.directory:
                    comp.pop_dir()
                try:
                    destcomp.set(destvarname, srcval, srcname=srcname)
                    self.xfer_file(srccomp, srcvarname, comp, destvarname)
                except Exception, exc:
                    msg = "cannot transfer file from '%s' to '%s': %s" % \
                          (srcname, vname, exc)
                    self.raise_exception(msg, type(exc))
                finally:
                    if comp.directory:
                        comp.push_dir(comp.get_abs_directory())
            else:
                try:
                    destcomp.set(destvarname, srcval, srcname=srcname)
                except Exception, exc:
                    msg = "cannot set '%s' from '%s': %s" % \
                        (vname, srcname, exc)
                    self.raise_exception(msg, type(exc))
            destcomp.set_valid(destvarname, True)
            
        return updated

    def update_outputs(self, outnames):
        """Execute any necessary internal or predecessor components in order to
        make the specified output variables valid.
        """
        self.update_inputs(None, varnames=outnames)

    def check_config (self):
        """Verify that the configuration of this component is correct. This function is
        called once prior to the first execution of this Assembly, and prior to execution
        if any children are added or removed, or if self._call_check_config is True.
        """
        super(Assembly, self).check_config()
        for name, value in self._traits_meta_filter(required=True).items():
            if value.is_trait_type(Instance) and getattr(self, name) is None:
                self.raise_exception("required plugin '%s' is not present" %
                                     name, TraitError)                
        
    def get_valids(self, names):
        """Returns a list of boolean values indicating whether the
        named attributes are valid (True) or invalid (False). Entries
        in names may specify either direct traits of self or those
        of direct children of self, but no deeper in the hierarchy than 
        that.
        """
        valids = []
        for name in names:
            if self.trait(name):
                valids.append(self.get_valid(name))
            else:
                tup = name.split('.', 1)
                if len(tup) > 1:
                    comp = getattr(self, tup[0])
                    valids.append(comp.get_valid(tup[1]))
                else:
                    self.raise_exception("get_valids: unknown variable '%s'" %
                                         name, RuntimeError)
        return valids

    def invalidate_deps(self, varnames, notify_parent=False):
        """Mark all Variables invalid that depend on vars.
        Returns a list of our newly invalidated boundary outputs.
        """
        vargraph = self.get_var_graph()
        succ = vargraph.succ  #successor nodes in the graph
        stack = set(varnames)
        outs = []
        while len(stack) > 0:
            name = stack.pop()
            if name in vargraph:
                tup = name.split('.', 1)
                if len(tup)==1:
                    self.set_valid(name, False)
                else:
                    getattr(self, tup[0]).set_valid(tup[1], False)
            else:
                self.raise_exception("%s is not an io trait" % name,
                                     RuntimeError)
            successors = succ.get(name, [])
            for vname in successors:
                tup = vname.split('.', 1)
                if len(tup) == 1:  #boundary var or Component
                    if self.trait(vname).iostatus == 'out': # an output boundary var
                        outs.append(vname)
                else:  # a var from a child component 
                    compname, compvar = tup
                    comp = getattr(self, compname)
                    if comp.get_valid(compvar):  # node is a valid Variable
                        for newvar in comp.invalidate_deps([compvar]):
                            stack.add('.'.join([compname, newvar]))
                        stack.add(vname)
        
        if len(outs) > 0:
            for out in outs:
                self.set_valid(out, False)
            if notify_parent and self.parent:
                self.parent.invalidate_deps(['.'.join([self.name,n]) for n in outs], 
                                            notify_parent)
        return outs

    @staticmethod
    def xfer_file(src_comp, src_varname, dst_comp, dst_varname):
        """ Transfer src_comp.src_ref file to dst_comp.dst_ref file. """
        src_path = os.path.join(src_comp.get_abs_directory(), 
                                src_comp.get(src_varname+'.filename'))
        dst_path = os.path.join(dst_comp.get_abs_directory(), 
                                dst_comp.get(dst_varname+'.filename'))
        if src_path != dst_path:
            if src_comp.trait(src_varname).binary is True:
                mode = 'b'
            else:
                mode = ''
            filexfer(None, src_path, None, dst_path, mode)

