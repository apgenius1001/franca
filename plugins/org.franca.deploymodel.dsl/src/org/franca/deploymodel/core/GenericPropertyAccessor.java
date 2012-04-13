/*******************************************************************************
* Copyright (c) 2012 Harman International (http://www.harman.com).
* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v1.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-v10.html
*******************************************************************************/
package org.franca.deploymodel.core;

import java.util.List;

import org.franca.deploymodel.dsl.FDModelHelper;
import org.franca.deploymodel.dsl.fDeploy.FDBoolean;
import org.franca.deploymodel.dsl.fDeploy.FDComplexValue;
import org.franca.deploymodel.dsl.fDeploy.FDElement;
import org.franca.deploymodel.dsl.fDeploy.FDEnum;
import org.franca.deploymodel.dsl.fDeploy.FDInteger;
import org.franca.deploymodel.dsl.fDeploy.FDProperty;
import org.franca.deploymodel.dsl.fDeploy.FDPropertyDecl;
import org.franca.deploymodel.dsl.fDeploy.FDPropertyFlag;
import org.franca.deploymodel.dsl.fDeploy.FDSpecification;
import org.franca.deploymodel.dsl.fDeploy.FDString;
import org.franca.deploymodel.dsl.fDeploy.FDValue;
import org.franca.deploymodel.dsl.fDeploy.FDValueArray;

import com.google.common.collect.Lists;

/**
 * This class allows the type-safe access to property values for a given
 * Franca deployment specification. It also handles to return the correct
 * default values, if those have been defined in the specification and not
 * overriden by actual concrete property definitions.
 */
public class GenericPropertyAccessor {

	private final FDSpecification spec;
	
	/**
	 * Construct a GenericPropertyAccessor object from a FDSpecification.
	 * @param spec the FDSpecification
	 */
	public GenericPropertyAccessor (FDSpecification spec) {
		this.spec = spec;
	}
	
	
	public Boolean getBoolean (FDElement elem, String property) {
		FDValue val = getSingleValue(elem, property);
		if (val!=null && val instanceof FDBoolean) {
			return ((FDBoolean) val).getValue().equals("true");
		}
		return null;
	}

	public List<Boolean> getBooleanArray (FDElement elem, String property) {
		FDValueArray valarray = getValueArray(elem, property);
		if (valarray==null)
			return null;
		
		List<Boolean> vals = Lists.newArrayList();
		for(FDValue v : valarray.getValues()) {
			if (v instanceof FDBoolean) {
				vals.add(((FDBoolean) v).getValue().equals("true"));
			} else {
				return null;
			}
		}
		return vals;
	}


	public Integer getInteger (FDElement elem, String property) {
		FDValue val = getSingleValue(elem, property);
		if (val!=null && val instanceof FDInteger) {
			return ((FDInteger) val).getValue();
		}
		return null;
	}

	public List<Integer> getIntegerArray (FDElement elem, String property) {
		FDValueArray valarray = getValueArray(elem, property);
		if (valarray==null)
			return null;
		
		List<Integer> vals = Lists.newArrayList();
		for(FDValue v : valarray.getValues()) {
			if (v instanceof FDInteger) {
				vals.add(((FDInteger) v).getValue());
			} else {
				return null;
			}
		}
		return vals;
	}

	public String getString (FDElement elem, String property) {
		FDValue val = getSingleValue(elem, property);
		if (val!=null && val instanceof FDString) {
			return ((FDString) val).getValue();
		}
		return null;
	}
	
	public List<String> getStringArray (FDElement elem, String property) {
		FDValueArray valarray = getValueArray(elem, property);
		if (valarray==null)
			return null;
		
		List<String> vals = Lists.newArrayList();
		for(FDValue v : valarray.getValues()) {
			if (v instanceof FDString) {
				vals.add(((FDString) v).getValue());
			} else {
				return null;
			}
		}
		return vals;
	}


	public String getEnum (FDElement elem, String property) {
		FDValue val = getSingleValue(elem, property);
		if (val!=null && val instanceof FDEnum) {
			return ((FDEnum) val).getValue().getName();
		}
		return null;
	}

	public List<String> getEnumArray (FDElement elem, String property) {
		FDValueArray valarray = getValueArray(elem, property);
		if (valarray==null)
			return null;
		
		List<String> vals = Lists.newArrayList();
		for(FDValue v : valarray.getValues()) {
			if (v instanceof FDEnum) {
				vals.add(((FDEnum) v).getValue().getName());
			} else {
				return null;
			}
		}
		return vals;
	}


	
	// *****************************************************************************

	private FDValue getSingleValue (FDElement elem, String property) {
		FDComplexValue val = getValue(elem, property);
		if (val!=null) {
			return val.getSingle();
		}
		return null;
	}

	private FDValueArray getValueArray (FDElement elem, String property) {
		FDComplexValue val = getValue(elem, property);
		if (val!=null) {
			return val.getArray();
		}
		return null;
	}

	
	/**
	 * Get a property's value for a given FDElement. The property is defined
	 * by its name (as String). If there is no explicit value for this property,
	 * use the appropriate default. If this hasn't been defined either, return 
	 * null.
	 * 
	 * @param elem the Franca deployment element
	 * @param property the name of the property
	 * @return the property's value (might be a single value or an array)
	 */
	private FDComplexValue getValue (FDElement elem, String property) {
		// look if there is an explicit value for the property
		for(FDProperty prop : elem.getProperties()) {
			if (prop.getDecl().getName().equals(property)) {
				return prop.getValue();
			}
		}
		
		// didn't find, look for default value for this property
		List<FDPropertyDecl> decls = FDModelHelper.getAllPropertyDecls(spec, elem);
		for(FDPropertyDecl decl : decls) {
			if (decl.getName().equals(property)) {
				FDComplexValue dflt = getDefault(decl);
				if (dflt!=null)
					return dflt;
			}
		}

		// no explicit value, and no default value =>
		// must be an optional property which is not defined here
		return null;
	}

	
	private FDComplexValue getDefault (FDPropertyDecl decl) {
		for(FDPropertyFlag flag : decl.getFlags()) {
			if (flag.getDefault()!=null) {
				return flag.getDefault();
			}
		}
		return null;
	}
	
}
